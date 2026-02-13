local Animation = {}
Animation.__index = Animation

-- Utility: build quads from a sprite sheet laid out in a single row
local function buildQuads(img, frameW, frameH, border, spacing, count, trimTop)
    trimTop = trimTop or 0

    local quads = {}
    for i = 1, count do
        local x = border + (i - 1) * (frameW + spacing)
        local y = border + trimTop

        quads[i] = love.graphics.newQuad(
            x, y,
            frameW, frameH,
            img:getWidth(), img:getHeight()
        )
    end
    return quads
end

function Animation.new(imageOrPath, opts)
    opts = opts or {}
    local self = setmetatable({}, Animation)

    if type(imageOrPath) == "string" then
        self.image = love.graphics.newImage(imageOrPath)
    else
        self.image = imageOrPath
    end

    self.image:setFilter("nearest", "nearest")

    self.frameW          = opts.frameW or 24
    self.frameH          = opts.frameH or 24
    self.border          = opts.border or 1
    self.spacing         = opts.spacing or 1
    self.count           = opts.count or 23

    -- Trim pixels from the top of every frame (useful if sprites are vertically offset)
    self.trimTop         = opts.trimTop or 0

    self.quads           = buildQuads(
        self.image,
        self.frameW, self.frameH,
        self.border, self.spacing,
        self.count,
        self.trimTop
    )

    self.time            = 0
    self.index           = 1
    self.playing         = true
    self.flipX           = false

    self.clip            = { frames = { 1 }, fps = 1, loop = true }
    self.clips           = {}

    self.currentClipName = nil
    return self
end

function Animation:setImage(img)
    self.image = img
    self.image:setFilter("nearest", "nearest")

    -- rebuild quads with same frame params (image size can change, but for palette swap it won't)
    self.quads = buildQuads(
        self.image,
        self.frameW, self.frameH,
        self.border, self.spacing,
        self.count,
        self.trimTop
    )
end

function Animation:addClip(name, frames, fps, loop)
    self.clips[name] = {
        frames = frames,
        fps    = fps or 8,
        loop   = (loop ~= false)
    }
end

function Animation:play(name, force)
    local nextClip = self.clips[name]
    if not nextClip then return end

    if not force and self.clip == nextClip then
        return
    end

    self.clip = nextClip
    self.currentClipName = name
    self.time = 0
    self.index = 1
    self.playing = true
end

function Animation:stop()
    self.playing = false
    self.time = 0
    self.index = 1
end

function Animation:setFrame(frameIndex)
    self.clip = { frames = { frameIndex }, fps = 1, loop = false }
    self.time = 0
    self.index = 1
end

function Animation:update(dt)
    if not self.playing then return end
    if #self.clip.frames <= 1 then return end

    local frameTime = 1 / self.clip.fps
    self.time = self.time + dt

    while self.time >= frameTime do
        self.time = self.time - frameTime
        self.index = self.index + 1

        if self.index > #self.clip.frames then
            if self.clip.loop then
                self.index = 1
            else
                self.index = #self.clip.frames
                self.playing = false
                break
            end
        end
    end
end

function Animation:draw(x, y, r, sx, sy, ox, oy)
    r                = r or 0
    sx               = sx or 1
    sy               = sy or 1
    ox               = ox or 0
    oy               = oy or 0

    -- Snap to pixels to prevent jitter
    x                = math.floor(x + 0.5)
    y                = math.floor(y + 0.5)

    -- Pick current frame from current clip + index
    local frameIndex = self.clip.frames[self.index] or 1
    local quad       = self.quads[frameIndex]
    if not quad then return end

    -- Correct flip pivot: compensate origin when using negative scale
    if self.flipX then
        local _, _, qw = quad:getViewport()
        sx = -sx
        ox = qw - ox
    end

    love.graphics.draw(self.image, quad, x, y, r, sx, sy, ox, oy)
end

return Animation
