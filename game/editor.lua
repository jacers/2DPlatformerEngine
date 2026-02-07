local Rectangle = require("entities.rectangle")
local Sheep     = require("entities.sheep")
require("helpers.constants")

local editor = {}

function editor.new(entityHandler, keyboard, window)
    local self = {}

    self.spawnTools = {
        spawn_rectangle = {
            label = "Rectangle",
            factory = function(x, y) return Rectangle(x, y, 160, 32) end
        },
        spawn_sheep = {
            label = "Sheep",
            factory = function(x, y) return Sheep(x, y) end
        }
    }

    self.spawnMode    = false
    self.spawnFactory = nil
    self.spawnLabel   = ""
    self.activeEntity = nil

    self.player = nil -- set by game

    function self:setPlayer(p)
        self.player = p
    end

    local function enterSpawnMode(label, factoryFn)
        self.spawnMode    = true
        self.spawnLabel   = label
        self.spawnFactory = factoryFn
    end

    local function exitSpawnMode()
        self.spawnMode    = false
        self.spawnLabel   = ""
        self.spawnFactory = nil
    end

    function self:isSpawnMode()
        return self.spawnMode
    end

    function self:update(dt)
        -- Editor movement (substepped by Game)
        local dx, dy = 0, 0
        local speed = EDITOR_MOVE_SPEED

        if keyboard.pressed("up")    then dy = dy - speed * dt end
        if keyboard.pressed("down")  then dy = dy + speed * dt end
        if keyboard.pressed("left")  then dx = dx - speed * dt end
        if keyboard.pressed("right") then dx = dx + speed * dt end

        if dx ~= 0 or dy ~= 0 then
            if self.spawnMode then
                entityHandler.moveAllByName(self.spawnLabel, dx, dy)
            elseif self.activeEntity and self.activeEntity ~= self.player and not self.activeEntity.dead then
                entityHandler.tryMove(self.activeEntity, dx, dy)
            end
        end
    end

    function self:draw()
        -- Spawn preview
        if self.spawnMode and self.spawnFactory then
            local mx, my = love.mouse.getPosition()
            local vx, vy = window.screenToWorld(mx, my)

            local preview = self.spawnFactory(vx, vy)
            preview.x = vx - preview.width / 2
            preview.y = vy - preview.height / 2

            if entityHandler.canPlace(preview) then
                love.graphics.setColor(1, 1, 1, 0.5)
            else
                love.graphics.setColor(1, 0.3, 0.3, 0.5)
            end
            preview:draw()
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- UI text (drawn on canvas by Game)
        if self.spawnMode then
            love.graphics.print(
                "Spawn mode: " .. self.spawnLabel .. " (click to place, Esc to cancel)",
                10, 10
            )
        elseif self.activeEntity and not self.activeEntity.dead then
            love.graphics.print(
                "Selected: " .. (self.activeEntity.name or "Entity") .. " (right click deletes)",
                10, 10
            )
        else
            love.graphics.print(
                "Left click selects, right click deletes | Space = jump",
                10, 10
            )
        end
    end

    function self:keypressed(key)
        if key == "escape" then
            exitSpawnMode()
            return true
        end

        -- Toggle spawn tools
        for action, tool in pairs(self.spawnTools) do
            if keyboard.pressed(action) then
                if self.spawnMode and self.spawnLabel == tool.label then
                    exitSpawnMode()
                else
                    enterSpawnMode(tool.label, tool.factory)
                end
                return true
            end
        end

        return false
    end

    function self:mousepressed(x, y, button)
        -- ignore clicks outside viewport (optional, but nice)
        if window.isInsideViewport and not window.isInsideViewport(x, y) then
            return false
        end

        local vx, vy = window.screenToWorld(x, y)

        if self.spawnMode and button == 1 and self.spawnFactory then
            local ent = self.spawnFactory(vx, vy)
            ent.x = vx - ent.width / 2
            ent.y = vy - ent.height / 2

            if entityHandler.canPlace(ent) then
                entityHandler.spawn(ent)
                self.activeEntity = ent
                exitSpawnMode()
            end
            return true
        end

        if button == 1 then
            self.activeEntity = entityHandler.pick(vx, vy)
            return true
        elseif button == 2 then
            local target = entityHandler.pick(vx, vy)
            if target and target ~= self.player then
                target:destroy()
                if target == self.activeEntity then self.activeEntity = nil end
            end
            return true
        end

        return false
    end

    return self
end

return editor
