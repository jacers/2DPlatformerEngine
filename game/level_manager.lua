local entityHandler = require("helpers.entity_handler")

local level_manager = {}

level_manager.levels = {
    "levels.level01",
    -- add more: "levels.level02", ...
}

level_manager.index = 1
level_manager.current = nil
level_manager.currentName = nil
level_manager.ctx = nil

function level_manager.load(i)
    level_manager.index = i or level_manager.index

    local name = level_manager.levels[level_manager.index]
    assert(name, "No level at index " .. tostring(level_manager.index))

    -- Clear existing world
    entityHandler.clear()

    -- Load module fresh (optional but great for iteration)
    package.loaded[name] = nil
    local level = require(name)

    level_manager.current = level
    level_manager.currentName = name

    -- Spawn returns a context
    level_manager.ctx = level.spawn(entityHandler) or {}

    return level_manager.ctx
end

function level_manager.reset()
    return level_manager.load(level_manager.index)
end

function level_manager.next()
    local nextIndex = level_manager.index + 1
    if nextIndex > #level_manager.levels then
        nextIndex = 1
    end
    return level_manager.load(nextIndex)
end

function level_manager.update(dt)
    if level_manager.current and level_manager.current.update then
        level_manager.current.update(dt, level_manager.ctx)
    end
end

return level_manager
