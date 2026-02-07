local entityHandler = require("helpers.entity_handler")
local tick          = require("libraries.tick")
local keyboard      = require("helpers.keyboard")
local window        = require("helpers.window")
local camera        = require("helpers.camera")

local levelManager  = require("game.level_manager")
local editorFactory = require("game.editor")

local game          = {}

function game.load()
    window.load()

    -- Camera uses virtual resolution
    camera.setViewportSize(window.width, window.height)

    -- Load first level
    local ctx = levelManager.load(1)
    game.player = ctx.player

    -- Camera follow + bounds
    camera.reset(0, 0)
    if ctx.player then camera.setTarget(ctx.player) end
    if ctx.bounds then
        camera.setBounds(ctx.bounds.x, ctx.bounds.y, ctx.bounds.w, ctx.bounds.h)
    else
        camera.setBounds(0, 0, window.width, window.height)
    end

    -- Editor
    game.editor = editorFactory.new(entityHandler, keyboard, window)
    game.editor:setPlayer(game.player)

    -- tuning
    game.maxDt = 0.1
    game.step  = 1 / 120
end

function game.update(dt)
    dt = math.min(dt, game.maxDt)

    while dt > 0 do
        local sdt = math.min(game.step, dt)
        dt = dt - sdt

        tick.update(sdt)
        entityHandler.update(sdt)
        game.editor:update(sdt)

        -- Editor movement substepped
        game.editor:update(sdt)

        -- Camera after physics
        camera.update(sdt)
    end
end

function game.draw()
    window.beginDraw()

    -- World (camera space)
    camera.apply()
    entityHandler.draw()
    camera.clear()

    -- UI (screen space)
    game.editor:draw()

    window.endDraw()
end

function game.keypressed(key)
    -- Editor gets first dibs
    if game.editor:keypressed(key) then
        return
    end

    -- Player jump (only when not spawning)
    if game.player and not game.editor:isSpawnMode() and keyboard.keypressed(key, "jump") then
        game.player:queueJump()
    end
end

function game.mousepressed(x, y, button)
    game.editor:mousepressed(x, y, button)
end

function game.resize(w, h)
    window.resizeGame(w, h)
end

return game
