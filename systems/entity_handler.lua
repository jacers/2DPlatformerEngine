local entityHandler = {}
local entities = {}

local physics = require("systems.physics")

-- If an entity provides :getHitbox(), use it
local function getBox(e)
    if e and e.getHitbox then
        local x, y, w, h = e:getHitbox()
        return { x = x, y = y, w = w, h = h }
    end
    return { x = e.x, y = e.y, w = e.width, h = e.height }
end

-- Axis-Aligned Bounding Box (uses hitboxes if present)
local function aabb(a, b)
    local A = getBox(a)
    local B = getBox(b)

    return
        A.x < B.x + B.w and
        A.x + A.w > B.x and
        A.y < B.y + B.h and
        A.y + A.h > B.y
end

-- Birthing and living
function entityHandler.spawn(entity)
    table.insert(entities, entity)
end

function entityHandler.update(dt)
    -- Timers / one-way drop-through, etc.
    physics.updateBodyTimersWorld(entities, dt)

    -- Moving platforms should move BEFORE entities update so riders are carried smoothly
    physics.updatePlatforms(entities, dt)

    -- Entity updates (player calls movePlatformer here)
    for i = #entities, 1, -1 do
        local entity = entities[i]
        entity:update(dt)

        if entity.dead then
            table.remove(entities, i)
        end
    end

    -- Triggers are evaluated AFTER movement for this frame
    physics.updateTriggers(entities)
end

function entityHandler.draw()
    for _, entity in ipairs(entities) do
        entity:draw()
    end
end

-- Picking (editor)
function entityHandler.pick(x, y)
    for i = #entities, 1, -1 do
        local e = entities[i]
        if e.containsPoint and e:containsPoint(x, y) then
            return e
        end
    end
    return nil
end

-- Collision helpers (editor placement)
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
                entity.x = oldX
                entity.y = oldY
                return false
            end
        end
    end

    return true
end

-- Platformer motion delegates to physics system
function entityHandler.movePlatformer(body, dx, dy)
    return physics.movePlatformer(entities, body, dx, dy)
end

-- Getter so we can iterate entities from outside
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
