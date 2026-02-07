local Rectangle     = require("entities.rectangle")
local Sheep         = require("entities.sheep")
local Player        = require("entities.player")

local entityHandler = require("helpers.entity_handler")
local tick          = require("libraries.tick")
local keyboard      = require("helpers.keyboard")
require("helpers.utilities")

-- Spawn tools
local spawnTools   = {
    spawn_rectangle = {
        label = "Rectangle",
        factory = function(x, y)
            return Rectangle(x, y, 160, 32)
        end
    },
    spawn_sheep = {
        label = "Sheep",
        factory = function(x, y)
            return Sheep(x, y)
        end
    }
}

local spawnMode    = false
local spawnFactory = nil
local spawnLabel   = ""
local activeEntity = nil

local player       = nil

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

function love.load()
    -- Simple level
    entityHandler.spawn(Rectangle(40, 520, 900, 40))  -- ground
    entityHandler.spawn(Rectangle(220, 420, 220, 32)) -- platform
    entityHandler.spawn(Rectangle(520, 340, 220, 32)) -- platform
    entityHandler.spawn(Rectangle(740, 260, 180, 32)) -- platform

    player = Player(80, 200)
    entityHandler.spawn(player)
end

function love.update(dt)
    tick.update(dt)
    entityHandler.update(dt)

    -- Keep your “edit/spawn mode” movement logic, but don’t move player as a selected entity
    local dx, dy = 0, 0
    local speed = 200

    if keyboard.pressed("up") then dy = dy - speed * dt end
    if keyboard.pressed("down") then dy = dy + speed * dt end
    if keyboard.pressed("left") then dx = dx - speed * dt end
    if keyboard.pressed("right") then dx = dx + speed * dt end

    if dx ~= 0 or dy ~= 0 then
        if spawnMode then
            entityHandler.moveAllByName(spawnLabel, dx, dy)
        elseif activeEntity and activeEntity ~= player and not activeEntity.dead then
            entityHandler.tryMove(activeEntity, dx, dy)
        end
    end
end

function love.draw()
    entityHandler.draw()

    if spawnMode and spawnFactory then
        local mx, my = love.mouse.getPosition()
        local preview = spawnFactory(mx, my)
        preview.x = mx - preview.width / 2
        preview.y = my - preview.height / 2

        if entityHandler.canPlace(preview) then
            love.graphics.setColor(1, 1, 1, 0.5)
        else
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
        end
        preview:draw()
        love.graphics.setColor(1, 1, 1, 1)
    end

    if spawnMode then
        love.graphics.print("Spawn mode: " .. spawnLabel .. " (click to place, Esc to cancel)", 10, 10)
    elseif activeEntity and not activeEntity.dead then
        love.graphics.print("Selected: " .. (activeEntity.name or "Entity") .. " (right click deletes)", 10, 10)
    else
        love.graphics.print("Left click selects, right click deletes | Space = jump", 10, 10)
    end
end

function love.keypressed(key)
    if key == "escape" then
        exitSpawnMode()
        return
    end

    if key == "space" and player and not spawnMode then
        player:jump()
    end

    -- Toggle spawn tools
    for action, tool in pairs(spawnTools) do
        if keyboard.pressed(action) then
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
        local ent = spawnFactory(x, y)
        ent.x = x - ent.width / 2
        ent.y = y - ent.height / 2

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
        if target and target ~= player then
            target:destroy()
            if target == activeEntity then activeEntity = nil end
        end
    end
end
