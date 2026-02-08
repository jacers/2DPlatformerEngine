local scene = require("scenes.gameplay.scene")

function love.load()
    scene.load()
end

function love.update(dt)
    scene.update(dt)
end

function love.draw()
    scene.draw()
end

function love.keypressed(key)
    scene.keypressed(key)
end

function love.gamepadpressed(joystick, button)
    scene.gamepadpressed(joystick, button)
end

function love.resize(w, h)
    scene.resize(w, h)
end

function love.errorhandler(msg)
    print((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1))):gsub("\n[^\n]+$", ""))
end
