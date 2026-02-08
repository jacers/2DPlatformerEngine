require("helpers.constants")

local entityHandler = require("helpers.entity_handler")
local tick          = require("libraries.tick")

local keyboard      = require("helpers.controls.keyboard")
local gamepad       = require("helpers.controls.gamepad")

local window        = require("helpers.window")
local camera        = require("helpers.camera")

local levelManager  = require("game.level_manager")
local editorFactory = require("game.editor")

local game = {}

function game.load()
    window.load()

    -- Camera uses virtual resolution
    camera.setViewportSize(window.width, window.height)
    camera.reset(0, 0)

    local ctx = levelManager.load(1)
    game.player = ctx.player

    if game.player then
        camera.setTarget(game.player)
    end
    if ctx.bounds then
        camera.setBounds(ctx.bounds.x, ctx.bounds.y, ctx.bounds.w, ctx.bounds.h)
    else
        camera.setBounds(0, 0, window.width, window.height)
    end

    game.editor = editorFactory.new(entityHandler, keyboard, window)
    game.editor:setPlayer(game.player)
end

function game.update(dt)
    dt = math.min(dt, MAX_FRAME_DT)

    while dt > 0 do
        local sdt = math.min(PHYSICS_STEP, dt)
        dt = dt - sdt

        tick.update(sdt)
        entityHandler.update(sdt)
        levelManager.update(sdt)

        game.editor:update(sdt)
        camera.update(sdt)
    end
end

function game.draw()
    window.beginDraw()

    -- World
    camera.apply()
    entityHandler.draw()
    camera.clear()

    -- UI / editor overlay (screen space)
    game.editor:draw()

    window.endDraw()
end

function game.keypressed(key)
    -- Let editor handle escape/tool toggles first
    if game.editor:keypressed(key) then
        return
    end

    -- Jump buffer (keyboard)
    if game.player and not game.editor:isSpawnMode() and keyboard.actionPressedAny(key, "jump") then
        game.player:queueJump()
        return
    end
end

function game.gamepadpressed(joystick, button)
    -- Record the controller edge press so gamepad.pressed(action) can consume it
    gamepad.gamepadpressed(button)

    -- Jump buffer (controller)
    if game.player and not game.editor:isSpawnMode() and keyboard.actionPressedAny(nil, "jump") then
        game.player:queueJump()
        return
    end
end

function game.mousepressed(x, y, button)
    game.editor:mousepressed(x, y, button)
end

function game.resize(w, h)
    window.resizeGame(w, h)
end

return game
