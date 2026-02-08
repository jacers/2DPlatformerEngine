local gamepad = require("helpers.controls.gamepad")

local keyboard = {}

local input = {
    -- General movement
    up              = { "w", "up" },
    down            = { "s", "down" },
    left            = { "a", "left" },
    right           = { "d", "right" },

    -- Player movement
    jump            = { "space", "l" },
    run             = { "lshift", "rshift", "k" },

    -- Editor
    spawn_rectangle = { "q", "h" },
    spawn_sheep     = { "e", "j" },
}

-- Returns true while any key for the action is held
function keyboard.pressed(action)
    local keys = input[action]
    if not keys then return false end

    for _, key in ipairs(keys) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    return false
end

-- Returns true only on the frame the key is pressed (call from love.keypressed)
function keyboard.keypressed(key, action)
    local keys = input[action]
    if not keys then return false end

    for _, k in ipairs(keys) do
        if key == k then
            return true
        end
    end
    return false
end

-- Held (movement, run, jump-hold, etc.)
function keyboard.actionDown(action)
    return keyboard.pressed(action) or gamepad.down(action)
end

-- Edge-triggered (jump buffer, toggles, menus)
-- Call from BOTH love.keypressed and love.gamepadpressed (via game routing)
function keyboard.actionPressedAny(key, action)
    local kb = false
    if key ~= nil then
        kb = keyboard.keypressed(key, action)
    end
    local gp = gamepad.pressed(action) -- consumes stored gamepad press
    return kb or gp
end

-- Horizontal movement: analog stick preferred, keyboard fallback
function keyboard.moveX()
    local ax = gamepad.moveX()
    if math.abs(ax) > 0 then
        return ax
    end

    local move = 0
    if keyboard.pressed("left") then move = move - 1 end
    if keyboard.pressed("right") then move = move + 1 end
    return move
end

return keyboard
