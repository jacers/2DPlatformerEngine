require("core.constants")

local entityHandler = require("systems.entity_handler")
local BaseEntity    = require("entities.entity")
local tick          = require("libraries.tick")

local keyboard      = require("core.input.keyboard")
local gamepad       = require("core.input.gamepad")

local window        = require("core.window")
local camera        = require("core.camera")

local levelManager  = require("scenes.gameplay.level_manager")

local pause         = require("scenes.pause.scene")

local altimeter     = require("systems.altimeter")

local scene         = {}

local function snapCameraToEntity(ent)
    if not ent then return end

    -- Effective viewport in world units depends on zoom
    local vw = window.width / camera.scale
    local vh = window.height / camera.scale

    local cx = (ent.x + (ent.width or 0) / 2) - vw / 2
    local cy = (ent.y + (ent.height or 0) / 2) - vh / 2

    camera.reset(cx, cy)
end

function scene.load()
    window.load()

    -- Camera uses virtual resolution
    camera.setViewportSize(window.width, window.height)
    camera.reset(0, 0)

    local ctx = levelManager.load(1)
    scene.player = ctx.player
    altimeter.reset(scene.player)

    -- Bounds MUST come from the level, otherwise you'll clamp to the top-left screen
    if ctx.bounds then
        camera.setBounds(ctx.bounds.x, ctx.bounds.y, ctx.bounds.w, ctx.bounds.h)
    else
        -- fallback: large world, not screen size
        camera.setBounds(0, 0, 999999, 999999)
    end

    if scene.player then
        camera.setTarget(scene.player)
        snapCameraToEntity(scene.player) -- <- See the level immediately
    end
end

function scene.update(dt)
    dt = math.min(dt, MAX_FRAME_DT)

    if pause.isPaused then
        return
    end

    while dt > 0 do
        local sdt = math.min(PHYSICS_STEP, dt)
        dt = dt - sdt

        tick.update(sdt)
        entityHandler.update(sdt)
        levelManager.update(sdt)
        altimeter.update(sdt, scene.player)

        camera.update(sdt)
    end
end

function scene.draw()
    window.beginDraw()

    -- World
    camera.apply()
    entityHandler.draw()
    camera.clear()
    altimeter.draw(12)

    pause.drawOverlay()
    window.endDraw()
end

function scene.keypressed(key)
    if keyboard.actionPressed(key, "pause") then
        pause.toggle()
        return true
    end

    if scene.player and keyboard.actionPressedAny(key, "jump") then
        scene.player:queueJump()
        return
    end

    if scene.player and keyboard.actionPressedAny(key, "cycle_left") then
        scene.player:cycleSkin(-1)
        return
    end

    if scene.player and keyboard.actionPressedAny(key, "cycle_right") then
        scene.player:cycleSkin(1)
        return
    end

    if keyboard.actionPressed(key, "debug") then
        BaseEntity.debugHitboxes = not BaseEntity.debugHitboxes
        return
    end
end

function scene.gamepadpressed(joystick, button)
    gamepad.gamepadpressed(button)

    if keyboard.actionPressedAny(nil, "pause") then
        pause.toggle()
        return true
    end

    if scene.player and keyboard.actionPressedAny(nil, "jump") then
        scene.player:queueJump()
        return
    end

    if scene.player and keyboard.actionPressedAny(nil, "cycle_left") then
        scene.player:cycleSkin(-1)
        return
    end

    if scene.player and keyboard.actionPressedAny(nil, "cycle_right") then
        scene.player:cycleSkin(1)
        return
    end

    if keyboard.actionPressedAny(nil, "debug") then
        BaseEntity.debugHitboxes = not BaseEntity.debugHitboxes
        return
    end
end

function scene.resize(w, h)
    window.resizeGame(w, h)
end

return scene
