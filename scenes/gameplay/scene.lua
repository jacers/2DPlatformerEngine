require("core.constants")

local entityHandler = require("systems.entity_handler")
local tick          = require("libraries.tick")

local keyboard      = require("core.input.keyboard")
local gamepad       = require("core.input.gamepad")

local window        = require("core.window")
local camera        = require("core.camera")

local levelManager  = require("scenes.gameplay.level_manager")
local editorFactory = require("scenes.gameplay.editor")

local pause         = require("scenes.pause.scene")

local scene         = {}

function scene.load()
    window.load()

    -- Camera uses virtual resolution
    camera.setViewportSize(window.width, window.height)
    camera.reset(0, 0)

    local ctx = levelManager.load(1)
    scene.player = ctx.player

    if scene.player then
        camera.setTarget(scene.player)
    end
    if ctx.bounds then
        camera.setBounds(ctx.bounds.x, ctx.bounds.y, ctx.bounds.w, ctx.bounds.h)
    else
        camera.setBounds(0, 0, window.width, window.height)
    end

    scene.editor = editorFactory.new(entityHandler, keyboard, window)
    scene.editor:setPlayer(scene.player)
end

function scene.update(dt)
    dt = math.min(dt, MAX_FRAME_DT)

    -- If paused: freeze everything (no tick, physics, editor, camera)
    if pause.isPaused then
        return
    end

    while dt > 0 do
        local sdt = math.min(PHYSICS_STEP, dt)
        dt = dt - sdt

        tick.update(sdt)
        entityHandler.update(sdt)
        levelManager.update(sdt)

        scene.editor:update(sdt)
        camera.update(sdt)
    end
end

function scene.draw()
    window.beginDraw()

    -- World
    camera.apply()
    entityHandler.draw()
    camera.clear()

    -- UI / editor overlay (screen space)
    scene.editor:draw()

    -- Pause overlay (drawn on canvas so it scales)
    pause.drawOverlay()

    window.endDraw()
end

function scene.keypressed(key)
    -- Pause game with key
    if keyboard.actionPressed(key, "pause") then
        pause.toggle()
        return true
    end

    -- Let editor handle escape/tool toggles first
    if scene.editor:keypressed(key) then
        return
    end

    -- Jump buffer (keyboard)
    if scene.player and not scene.editor:isSpawnMode() and keyboard.actionPressedAny(key, "jump") then
        scene.player:queueJump()
        return
    end
end

function scene.gamepadpressed(joystick, button)
    -- Record the controller edge press so gamepad.pressed(action) can consume it
    gamepad.gamepadpressed(button)

    -- Pause
    if keyboard.actionPressedAny(nil, "pause") then
        pause.toggle()
        return true
    end

    -- Jump buffer (controller)
    if scene.player and not scene.editor:isSpawnMode() and keyboard.actionPressedAny(nil, "jump") then
        scene.player:queueJump()
        return
    end
end

function scene.mousepressed(x, y, button)
    scene.editor:mousepressed(x, y, button)
end

function scene.resize(w, h)
    window.resizeGame(w, h)
end

return scene
