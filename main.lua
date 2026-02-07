local game = require("game.game")

function love.load() game.load() end
function love.update(dt) game.update(dt) end
function love.draw() game.draw() end
function love.keypressed(key) game.keypressed(key) end
function love.mousepressed(x, y, button) game.mousepressed(x, y, button) end
function love.resize(w, h) game.resize(w, h) end

function love.errorhandler(msg)
    print((debug.traceback("Error: " .. tostring(msg), 1 + (layer or 1))):gsub("\n[^\n]+$", ""))
end
