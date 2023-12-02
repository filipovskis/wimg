--[[

Copyright (c) 2022 Aleksandrs Filipovskis

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

--]]

wimg = wimg or {}
wimg.cache = wimg.cache or {}
-- wimg.proxy = 'https://proxy.duckduckgo.com/iu/?u=' -- it seems imgur has banned duckduckgo's proxy at 29/04/2023, you can try to enable it
wimg.proxy = ''

local wimg = wimg

local function printWarning(text)
    MsgC(color_white, '(', Color(153, 0, 255), 'wimg', color_white, ') ', text)
end

-- ANCHOR Queue

local addInQueue
do
    local http_Fetch = http.Fetch
    local table_remove = table.remove
    local file_Exists = file.Exists
    local file_Write = file.Write
    local insert = table.insert

    local basePath = 'wimg'
    local queue = {}
    local rate = 1 / 5

    if not file_Exists(basePath, 'DATA') then
        file.CreateDir(basePath)
    end

    local function findMaterial(name, format, parameters)
        local path = basePath .. '/' .. name .. format

        if file_Exists(path, 'DATA') then
            return Material('data/' .. path, parameters)
        end
    end

    local function saveMaterial(name, format, body)
        local path = basePath .. '/' .. name .. format

        file_Write(path, body)
    end

    function addInQueue(wimgObject)
        local name = wimgObject:GetName()
        local url = wimgObject:GetURL()
        local format = wimgObject:GetFormat()
        local params = wimgObject:GetParameters()
        local mat = findMaterial(name, format, params)

        if mat then
            wimgObject:SetMaterial(mat)
        else
            insert(queue, {
                name = name,
                url = url,
                format = format,
                parameters = params,
                wimgObject = wimgObject
            })
        end
    end

    timer.Create('wimg.ProcessQueue', rate, 0, function()
        local data = queue[1]
        if data then
            table_remove(queue, 1)

            local name = data.name
            local url = data.url
            local format = data.format
            local parameters = data.parameters
            local wimgObject = data.wimgObject

            local success, errorString = pcall(function()
                local mat = findMaterial(name, format, parameters)
                if mat then
                    wimgObject:SetMaterial(mat)
                else
                    http_Fetch(wimg.proxy .. url, function(body, size, headers, code)
                        if code > 200 then
                            printWarning('Failed to fetch material (code: ' .. tostring(code) .. '), url: ' .. url)
                            return
                        end

                        saveMaterial(name, format, body)

                        local mat = findMaterial(name, format, parameters)
                        if mat and wimgObject then
                            wimgObject:SetMaterial(mat)
                        else
                            printWarning('Failed to fetch material after download! (url: ' .. url .. ')')
                        end
                    end, function()
                        printWarning(Format('Failed to download the image with name: \"%s\", url: %s', name, url))
                    end)
                end
            end)

            if not success then
                printWarning('Error occured during image catchup: ' .. errorString)
            end
        end
    end)
end

-- ANCHOR Class

local WIMAGE = {}
WIMAGE.__index = WIMAGE

function WIMAGE.__eq(a, b)
    return a:GetName() == b:GetName()
end

AccessorFunc(WIMAGE, 'm_Name', 'Name')
AccessorFunc(WIMAGE, 'm_URL', 'URL')
AccessorFunc(WIMAGE, 'm_Format', 'Format')
AccessorFunc(WIMAGE, 'm_Material', 'Material')
AccessorFunc(WIMAGE, 'm_Parameters', 'Parameters')

do
    local SetDrawColor = surface.SetDrawColor
    local DrawTexturedRect = surface.DrawTexturedRect
    local SetMaterial = surface.SetMaterial
    local DrawTexturedRectRotated = surface.DrawTexturedRectRotated

    function WIMAGE:Draw(x, y, w, h, color)
        color = color or color_white

        local mat = self.m_Material

        if mat then
            SetDrawColor(color)
            SetMaterial(mat)
            DrawTexturedRect(x, y, w, h)
        end
    end

    function WIMAGE:DrawRotated(x, y, w, h, r, color)
        color = color or color_white

        local mat = self.m_Material

        if mat then
            SetDrawColor(color)
            SetMaterial(mat)
            DrawTexturedRectRotated(x, y, w, h, r)
        end
    end
end

function WIMAGE:Download()
    addInQueue(self)
end

function WIMAGE:GetWidth()
    return self.m_Material and self.m_Material:Width() or 0
end

function WIMAGE:GetTall()
    return self.m_Material and self.m_Material:Height() or 0
end

WIMAGE.__call = WIMAGE.Draw

-- ANCHOR Library

function wimg.Register(name, url)
    assert(name, 'No name provided')
    assert(url, 'No URL provided')
    wimg.cache[name] = url
end

function wimg.Create(name, parameters)
    assert(name, 'No name provided')

    local url = wimg.cache[name]
    local invalid = false

    if not url then
        ErrorNoHalt('There\'s no web image registered with name: ' .. name)
        invalid = true
    end

    local format = invalid and '_INVALID_' or string.match(url, '.%w+$')
    assert(format, 'wrong format for this url: ' .. url .. ' (' .. name ..  ')')

    local obj = setmetatable({
        m_Name = name,
        m_URL = url,
        m_Format = format,
        m_Parameters = parameters
    }, WIMAGE)

    if not invalid then
        obj:Download()
    end

    return obj
end

do
    local urlCache = {}

    local function encodeURL(url)
        return util.CRC(url)
    end

    function wimg.Simple(url, parameters)
        assert(url, 'No URL provided')
        assert(isstring(url), 'URL should be string!')

        if not urlCache[url] then
            urlCache[url] = encodeURL(url)
        end

        local uid = urlCache[url]

        wimg.Register(uid, url)

        return wimg.Create(uid, parameters)
    end
end

-- ANCHOR Test Section
--[[
    do
        wimg.Register('user', 'https://i.imgur.com/Q3OHblv.png')

        local userSmooth = wimg.Create('user', 'smooth mips')
        local userSharp = wimg.Create('user')
        local userQuick = wimg.Simple('https://i.imgur.com/Q3OHblv.png')

        print(userSharp == userSmooth)

        hook.Add('HUDPaint', 'wimg.Test', function()
            local size = math.abs(math.sin(CurTime() * .5)) * 256

            userSmooth:Draw(0, 0, size, size)
            userSharp:Draw(size, 0, size, size)
            userQuick:Draw(size * 2, 0, size, size)
            userQuick(size * 3, 0, size, size)
        end)
    end
]]
