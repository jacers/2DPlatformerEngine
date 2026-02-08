local gamepad = {}

local input = {
    -- General movement
    up    = { "dpup" },
    down  = { "dpdown" },
    left  = { "dpleft" },
    right = { "dpright" },

    -- Player movement
    jump  = { "a", "b" },
    run   = { "x", "y" },

    -- Pause (+/- on Switch controller)
    pause = {"start", "back"},

    -- Analog stick movement (optional thresholds)
    stick = {
        enabled   = true,
        deadzone  = 0.25,
        leftAxis  = "leftx",
        upAxis    = "lefty",

        -- digital thresholds for up/down/left/right from stick
        threshold = 0.5,
    }
}

-- Internals

-- Pick which gamepad to use (first connected)
local function getPad()
    local pads = love.joystick.getJoysticks()
    return pads[1]
end

local function axisValue(pad, axis)
    if not pad then return 0 end
    local v = pad:getGamepadAxis(axis) or 0
    local dz = (input.stick and input.stick.deadzone) or 0.25
    if math.abs(v) < dz then return 0 end
    return v
end

local function anyDown(pad, buttons)
    if not pad or not buttons then return false end
    for _, b in ipairs(buttons) do
        if pad:isGamepadDown(b) then
            return true
        end
    end
    return false
end

-- Held inputs

function gamepad.down(action)
    local pad = getPad()
    if not pad then return false end

    -- Button mapping (jump/run/dpad etc.)
    if anyDown(pad, input[action]) then
        return true
    end

    -- Stick-as-dpad mapping
    if input.stick and input.stick.enabled then
        local t = input.stick.threshold or 0.5

        if action == "left" then return axisValue(pad, input.stick.leftAxis) < -t end
        if action == "right" then return axisValue(pad, input.stick.leftAxis) > t end
        if action == "up" then return axisValue(pad, input.stick.upAxis) < -t end
        if action == "down" then return axisValue(pad, input.stick.upAxis) > t end
    end

    return false
end

-- Analog movement for platformer (recommended)
function gamepad.moveX()
    local pad = getPad()
    if not pad then return 0 end

    if input.stick and input.stick.enabled then
        return axisValue(pad, input.stick.leftAxis)
    end

    return 0
end

-- Edge presses

local pressedThisFrame = {}

function gamepad.gamepadpressed(button)
    pressedThisFrame[button] = true
end

local function consume(button)
    if pressedThisFrame[button] then
        pressedThisFrame[button] = nil
        return true
    end
    return false
end

-- Returns true only on the frame the mapped button is pressed
function gamepad.pressed(action)
    local buttons = input[action]
    if not buttons then return false end

    for _, b in ipairs(buttons) do
        if consume(b) then
            return true
        end
    end

    return false
end

return gamepad
