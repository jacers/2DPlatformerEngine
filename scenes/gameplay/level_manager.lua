local entityHandler = require("systems.entity_handler")
local level_loader  = require("systems.level_loader")
require("core.constants")

local level_manager = {}

level_manager.levels = {
    { kind = "tiled", path = "levels/level01/initial_test.json" },
}

level_manager.index = 1
level_manager.current = nil
level_manager.currentName = nil
level_manager.ctx = nil

level_manager.playerFactory = nil
function level_manager.setPlayerFactory(fn)
    level_manager.playerFactory = fn
end

local function isTiledEntry(entry)
    return type(entry) == "table" and entry.kind == "tiled" and type(entry.path) == "string"
end

function level_manager.load(i)
    level_manager.index = i or level_manager.index

    local entry = level_manager.levels[level_manager.index]
    assert(entry, "No level at index " .. tostring(level_manager.index))

    entityHandler.clear()

    level_manager.current = nil
    level_manager.currentName = nil
    level_manager.ctx = {}

    if isTiledEntry(entry) then
        local info = level_loader.loadTiledJson(entityHandler, entry.path) or {}
        level_manager.ctx = info
        level_manager.currentName = entry.path

        -- Build bounds in pixels for camera
        if info.map then
            local mapWpx = (info.map.width or 0) * (info.map.tilewidth or 16)
            local mapHpx = (info.map.height or 0) * (info.map.tileheight or 16)
            info.bounds = { x = 0, y = 0, w = mapWpx, h = mapHpx }
        else
            info.bounds = { x = 0, y = 0, w = 0, h = 0 }
        end

        -- Spawn player
        if level_manager.playerFactory then
            local px, py = 80, 200
            if info.player_spawn then
                px, py = info.player_spawn.x, info.player_spawn.y

                -- Tiled point objects are usually at "feet"/bottom
                py = py - PLAYER.HEIGHT
            end

            local player = level_manager.playerFactory(px, py, info)
            if player then
                entityHandler.spawn(player)
                info.player = player
            end
        end

        return info
    end

    -- Lua module level fallback
    local name = entry
    assert(type(name) == "string", "Level entry must be a module string or a {kind='tiled', path='...'} table")

    package.loaded[name] = nil
    local level = require(name)

    level_manager.current = level
    level_manager.currentName = name
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
