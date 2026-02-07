local input = {
    up              = { "w", "up" },
    down            = { "s", "down" },
    left            = { "a", "left" },
    right           = { "d", "right" },
    spawn_rectangle = {"space", "q", "j"},
    spawn_sheep     = {"lshift", "e", "k"},
    spawn_dick      = {"tab", "r", "l"}
}

function pressed(action)
    for _, key in ipairs(input[action]) do
        if love.keyboard.isDown(key) then return true end
    end
    return false
end
