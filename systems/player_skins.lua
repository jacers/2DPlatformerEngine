local PaletteSwap = require("systems.palette_swap")
local BASE = "assets/images/scissortail.png"

local skins = {}

-- The three base colors of scissortail.png
local C1 = PaletteSwap.key(99, 155, 255)  -- Main feathers
local C2 = PaletteSwap.key(48, 96, 130)   -- Deeper color
local C3 = PaletteSwap.key(215, 123, 186) -- Hearts from looking up

skins.list = {
    {
        id = "scissortail",
        base = BASE,
        palette = {
            -- Gonna leave blank since it will just use the unchaged image
        }
    },
    {
        id = "pinktail",
        base = BASE,
        palette = {
            [C1] = { 215, 123, 186 }, -- Main feathers
            [C2] = { 118, 66, 138 },  -- Deeper color
            [C3] = { 99, 155, 255 },  -- Hearts from looking up
        }
    },
    {
        id = "greentail",
        base = BASE,
        palette = {
            [C1] = { 238, 195, 154 }, -- Main feathers
            [C2] = { 75, 105, 47 },   -- Deeper color
            [C3] = { 215, 123, 186 }, -- Hearts from looking up
        }
    },
    {
        id = "orangetail",
        base = BASE,
        palette = {
            [C1] = { 255, 147, 0 }, -- Main feathers
            [C2] = { 92, 51, 5 },   -- Deeper color
            [C3] = { 215, 123, 186 }, -- Hearts from looking up
        }
    },
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

-- Get the LOVE Image for current skin
function skins.currentImage()
    local s = skins.current()
    return PaletteSwap.getImage(s.base, s.palette)
end

-- Change one color of the current skin at runtime
-- oldRGB/newRGB are {r,g,b[,a]} in 0..255
function skins.setColor(oldRGB, newRGB)
    local s = skins.current()
    s.palette = s.palette or {}
    local k = PaletteSwap.key(oldRGB[1], oldRGB[2], oldRGB[3], oldRGB[4])
    s.palette[k] = newRGB
end

return skins
