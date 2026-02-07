local keyboard = {}

local input = {
    up              = { "w", "up" },
    down            = { "s", "down" },
    left            = { "a", "left" },
    right           = { "d", "right" },
    jump            = { "space", "l" },

    spawn_rectangle = { "q", "j" },
    spawn_sheep     = { "e", "k" },
}

function keyboard.pressed(action)
    for _, key in ipairs(input[action] or {}) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    return false
end

return keyboard
