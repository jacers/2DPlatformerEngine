require("core.constants")
local S = SCREEN

function love.conf(t)
    t.window.title      = "2D Platformer!"
    t.window.icon       = "assets/images/icon.jpg"
    t.window.width      = S.WIDTH
    t.window.height     = S.HEIGHT
    t.window.fullscreen = false
    t.window.resizable  = true
    t.window.vsync      = 1
end
