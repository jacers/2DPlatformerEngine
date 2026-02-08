local json      = require("libraries.json")
local Rectangle = require("entities.rectangle")
local Sheep     = require("entities.sheep")
local Player    = require("entities.player")

require("core.constants")

local level_loader = {}

local function readJson(path)
    -- Must be inside the LÖVE project; no io.open here.
    local info = love.filesystem.getInfo(path)
    if not info then
        error(
            "Level JSON not found in LÖVE filesystem: '" .. tostring(path) .. "'\n" ..
            "Make sure the file exists INSIDE your project folder and you're using a relative path.",
            2
        )
    end

    local contents, size = love.filesystem.read(path)
    if not contents then
        error("Failed to read JSON file: '" .. tostring(path) .. "'", 2)
    end

    local ok, data = pcall(json.decode, contents)
    if not ok then
        error("Failed to parse JSON '" .. tostring(path) .. "':\n" .. tostring(data), 2)
    end

    return data
end

local function findLayer(map, layerName, layerType)
    if not map.layers then return nil end
    for _, layer in ipairs(map.layers) do
        if layer.name == layerName and (not layerType or layer.type == layerType) then
            return layer
        end
    end
    return nil
end

local function spawnSolidsFromTileLayer(entityHandler, map, layer)
    local tw = map.tilewidth or 16
    local th = map.tileheight or 16
    local w  = layer.width or map.width
    local h  = layer.height or map.height

    if not layer.data then return end

    for i = 1, #layer.data do
        local gid = layer.data[i]
        if gid and gid ~= 0 then
            -- Your test tileset has firstgid=1 and only 1 tile.
            -- So gid==1 means solid.
            local idx = i - 1
            local tx = idx % w
            local ty = math.floor(idx / w)

            local x = tx * tw
            local y = ty * th

            local r = Rectangle(x, y, tw, th)
            r.solid = true
            entityHandler.spawn(r)
        end
    end
end

local function parseEntities(entityHandler, map, layer)
    local ctx = {
        map = map,
        player_spawn = nil,
        exits = {},
    }

    if not layer.objects then return ctx end

    for _, obj in ipairs(layer.objects) do
        local name = obj.name or ""
        local ox = obj.x or 0
        local oy = obj.y or 0

        if name == "player_spawn" then
            -- Tiled object y is usually the bottom edge for point objects
            -- We'll hand back a sane spawn point; your player factory can adjust if desired.
            ctx.player_spawn = { x = ox, y = oy }
        elseif name == "sheep" then
            entityHandler.spawn(Sheep(ox, oy))
        elseif name == "trigger_exit" then
            table.insert(ctx.exits, { x = ox, y = oy, width = obj.width or 0, height = obj.height or 0 })
        end
    end

    return ctx
end

function level_loader.loadTiledJson(entityHandler, path)
    local map = readJson(path)

    assert(map.type == "map", "Tiled JSON is not a map: " .. tostring(path))
    assert(map.layers, "Tiled JSON has no layers: " .. tostring(path))

    local solidsLayer   = findLayer(map, "Solids", "tilelayer")
    local entitiesLayer = findLayer(map, "Entities", "objectgroup")

    if solidsLayer then
        spawnSolidsFromTileLayer(entityHandler, map, solidsLayer)
    end

    local ctx
    if entitiesLayer then
        ctx = parseEntities(entityHandler, map, entitiesLayer)
    else
        ctx = { map = map, player_spawn = nil, exits = {} }
    end

    -- Map bounds for camera
    local worldW = (map.width or 0) * (map.tilewidth or 16)
    local worldH = (map.height or 0) * (map.tileheight or 16)
    ctx.bounds = { x = 0, y = 0, w = worldW, h = worldH }

    -- Spawn player at Tiled "player_spawn"
    if ctx.player_spawn then
        -- Tiled point objects: x/y are fine as a world position
        -- If you want spawn to mean "feet on ground", keep y as-is and let gravity settle.
        local px, py = ctx.player_spawn.x, ctx.player_spawn.y

        local player = Player(px, py)
        entityHandler.spawn(player)
        ctx.player = player
    else
        print("WARNING: No 'player_spawn' object found in Entities layer")
    end

    return ctx
end


return level_loader
