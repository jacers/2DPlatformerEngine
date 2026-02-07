local Rectangle = require("entities.rectangle")
local Sheep     = require("entities.sheep")

local entityHandler = require("helpers.entity_handler")
local tick          = require("libraries.tick")
require("helpers.utilities")
require("helpers.keyboard")

-- Spawn tools
local spawnTools = {
    spawn_rectangle = {
        label = "Rectangle",
        factory = function(x, y)
            return Rectangle(x, y)
        end
    },
    spawn_sheep = {
        label = "Sheep",
        factory = function(x, y)
            return Sheep(x, y)
        end
    }
}

-- Mode state
local spawnMode    = false
local spawnFactory = nil
local spawnLabel   = ""
local activeEntity = nil

-- Mode helpers
local function enterSpawnMode(label, factoryFn)
    spawnMode    = true
    spawnLabel   = label
    spawnFactory = factoryFn
end

local function exitSpawnMode()
    spawnMode    = false
    spawnLabel   = ""
    spawnFactory = nil
end

-- Love callbacks
function love.load()
    entityHandler.spawn(Rectangle(100, 50))
end

function love.update(dt)
    tick.update(dt)
    entityHandler.update(dt)

    local dx, dy = 0, 0
    local speed = 200

    if pressed("up")    then dy = dy - speed * dt end
    if pressed("down")  then dy = dy + speed * dt end
    if pressed("left")  then dx = dx - speed * dt end
    if pressed("right") then dx = dx + speed * dt end

    if dx ~= 0 or dy ~= 0 then
        if spawnMode then
            entityHandler.moveAllByName(spawnLabel, dx, dy)
        elseif activeEntity and not activeEntity.dead then
            entityHandler.tryMove(activeEntity, dx, dy)
        end
    end
end

function love.draw()
    entityHandler.draw()

    -- Display image at mouse coordinates
    if spawnMode and spawnFactory then
        local mx, my = love.mouse.getPosition()
        local preview = spawnFactory(mx, my)

        preview.x = mx - preview.width  / 2
        preview.y = my - preview.height / 2

        love.graphics.print(
            "(" .. mx .. ", " .. my .. ")",
            10, 25
        )

        -- Ghost preview
        if entityHandler.canPlace(preview) then
            love.graphics.setColor(1, 1, 1, 0.5)
        else
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
        end

        -- Draw preview
        if preview.draw then
            preview:draw()
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Display text in the top left
    if spawnMode then
        love.graphics.print(
            "Spawn mode: " .. spawnLabel ..
            " (arrows move all, click to place, Esc to cancel)",
            10, 10
        )
    elseif activeEntity and not activeEntity.dead then
        love.graphics.print(
            "Selected: " .. (activeEntity.name or "Entity") ..
            " (arrows move it, right click deletes)",
            10, 10
        )
    else
        love.graphics.print(
            "Select mode: left click selects, right click deletes",
            10, 10
        )
    end
end

function love.keypressed(key)
    if key == "escape" then
        exitSpawnMode()
        return
    end

    for action, tool in pairs(spawnTools) do
        if pressed(action) then
            if spawnMode and spawnLabel == tool.label then
                exitSpawnMode()
            else
                enterSpawnMode(tool.label, tool.factory)
            end
            return
        end
    end
end

function love.mousepressed(x, y, button)
    if spawnMode and button == 1 and spawnFactory then
        local mx, my = x, y

        -- Create entity once
        local ent = spawnFactory(mx, my)

        -- Center it exactly like the preview
        ent.x = mx - ent.width  / 2
        ent.y = my - ent.height / 2

        if entityHandler.canPlace(ent) then
            entityHandler.spawn(ent)
            activeEntity = ent
            exitSpawnMode()
        end

        return
    end


    if button == 1 then
        activeEntity = entityHandler.pick(x, y)
    elseif button == 2 then
        local target = entityHandler.pick(x, y)
        if target then
            target:destroy()
            if target == activeEntity then
                activeEntity = nil
            end
        end
    end
end

function love.errorhandler(msg)
    print(
        (debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1)))
            :gsub("\n[^\n]+$", "")
    )
end
