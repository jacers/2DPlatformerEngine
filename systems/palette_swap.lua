local PaletteSwap = {}

-- Cache base ImageData by path, and swapped Images by "path + palette signature"
local baseDataCache = {}
local imageCache = {}

local function rgba8_key(r8, g8, b8, a8)
    return ("%d,%d,%d,%d"):format(r8, g8, b8, a8 or 255)
end

local function normalizeColor(c)
    -- Accept {r,g,b} or {r,g,b,a} in 0-255 OR 0-1
    local r, g, b, a = c[1], c[2], c[3], c[4]

    if r <= 1 and g <= 1 and b <= 1 and (a == nil or a <= 1) then
        -- Already normalized
        return r, g, b, (a == nil and 1 or a)
    end

    -- Convert 0..255 to 0..1
    return r / 255, g / 255, b / 255, ((a == nil and 255 or a) / 255)
end

local function paletteSignature(palette)
    -- palette: map["r,g,b,a"] = {r,g,b,a}
    -- Make a stable signature so we can cache results.
    local keys = {}
    for k in pairs(palette or {}) do keys[#keys + 1] = k end
    table.sort(keys)

    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        local v = palette[k]
        local r, g, b, a = v[1], v[2], v[3], v[4] or 255
        parts[#parts + 1] = k .. "->" .. rgba8_key(r, g, b, a)
    end
    return table.concat(parts, "|")
end

local function getBaseData(path)
    local data = baseDataCache[path]
    if data then return data end

    data = love.image.newImageData(path)
    baseDataCache[path] = data
    return data
end

-- Public helper to build keys easily from RGB(A) 0..255
function PaletteSwap.key(r, g, b, a)
    return rgba8_key(r, g, b, a)
end

-- Creates/returns a swapped Image from:
--  - basePath: string
--  - palette: table mapping PaletteSwap.key(oldRGB) -> {newR,newG,newB[,newA]} (0..255)
-- opts:
--  - tolerance (integer 0..255): optional per-channel tolerance for matching (default 0 = exact)
function PaletteSwap.getImage(basePath, palette, opts)
    opts = opts or {}
    local tolerance = opts.tolerance or 0

    palette = palette or {}
    local cacheKey = basePath .. "::" .. paletteSignature(palette) .. "::tol=" .. tostring(tolerance)
    local cached = imageCache[cacheKey]
    if cached then return cached end

    local base = getBaseData(basePath)

    -- clone so we never mutate the cached base ImageData
    local out = base:clone()

    local function matchesWithTol(r8, g8, b8, a8, key)
        if tolerance <= 0 then
            return rgba8_key(r8, g8, b8, a8) == key
        end
        -- key is "r,g,b,a"
        local kr, kg, kb, ka = key:match("^(%d+),(%d+),(%d+),(%d+)$")
        kr, kg, kb, ka = tonumber(kr), tonumber(kg), tonumber(kb), tonumber(ka)

        return (math.abs(r8 - kr) <= tolerance)
            and (math.abs(g8 - kg) <= tolerance)
            and (math.abs(b8 - kb) <= tolerance)
            and (math.abs(a8 - ka) <= tolerance)
    end

    out:mapPixel(function(x, y, r, g, b, a)
        local r8 = math.floor(r * 255 + 0.5)
        local g8 = math.floor(g * 255 + 0.5)
        local b8 = math.floor(b * 255 + 0.5)
        local a8 = math.floor(a * 255 + 0.5)

        -- Fast path: exact lookup first
        local k = rgba8_key(r8, g8, b8, a8)
        local repl = palette[k]
        if repl then
            return normalizeColor(repl)
        end

        -- Optional tolerance path (slower): only if requested
        if tolerance > 0 then
            for key, rep in pairs(palette) do
                if matchesWithTol(r8, g8, b8, a8, key) then
                    return normalizeColor(rep)
                end
            end
        end

        return r, g, b, a
    end)

    local img = love.graphics.newImage(out)
    img:setFilter("nearest", "nearest")

    imageCache[cacheKey] = img
    return img
end

function PaletteSwap.clearCache()
    imageCache = {}
end

return PaletteSwap
