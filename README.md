A handy library to get images from the internet in Garry's Mod.

### 💡 Features
- The library uses proxy to get fetch HTTP requests
- The HTTP requests are placed in queue
- Simple syntax

### ✍️ Example
```lua=
-- You can assign an identifier to URL to reuse it after in different parts of code
wimg.Register('user', 'https://i.imgur.com/Q3OHblv.png')

-- Creates a web image instance without any parameters
local userSharp = wimg.Create('user')
-- Creates a web image instance with `smooth mips` parameters
local userSmooth = wimg.Create('user', 'smooth mips')
-- Registers URL and creates a web image instance (QUICK)
local userQuick = wimg.Simple('https://i.imgur.com/Q3OHblv.png')

print(userSharp == userSmooth)

hook.Add('HUDPaint', 'wimg.Test', function()
    local size = math.abs(math.sin(CurTime() * .5)) * 256

    -- Draw the images
    userSmooth:Draw(0, 0, size, size)
    userSharp:Draw(size, 0, size, size)
    userQuick:Draw(size * 2, 0, size, size)
    userQuick(size * 3, 0, size, size)
end)
```