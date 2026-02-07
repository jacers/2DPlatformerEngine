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

-- Group movement (spawn mode)
function entityHandler.moveAllByName(name, dx, dy)
    for _, e in ipairs(entities) do
        if e.name == name then
            entityHandler.tryMove(e, dx, dy)
        end
    end
end

return entityHandler
