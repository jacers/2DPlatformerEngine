local skins = {}

skins.list = {
    { id = "scissortail", path = "assets/images/player/scissortail.png" },
    { id = "pinktail",    path = "assets/images/player/pinktail.png" },
    { id = "greentail",   path = "assets/images/player/greentail.png" },
}

skins.index = 1

function skins.current()
    return skins.list[skins.index]
end

function skins.setIndex(i)
    local n = #skins.list
    if n == 0 then return skins.current() end

    -- wrap
    i = ((i - 1) % n) + 1
    skins.index = i
    return skins.current()
end

function skins.cycle(dir)
    dir = dir or 1
    return skins.setIndex(skins.index + dir)
end

return skins
