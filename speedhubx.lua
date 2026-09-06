--!strict
-- Steal An Egg Matcha port: SpeedHubX Egg Port
-- Standalone raw script. Upload this file to GitHub, then load with loadstring(httpget(raw_url))().

local env = getfenv()
local ui = env and env.UI

local SCRIPT_TITLE = "SpeedHubX Egg Port"
local API_KEY = "SpeedHubXEggPort"
local TAB_NAME = "SpeedHubX Egg"
local ID = "speedhubx_egg_"

local PRIOR_API_KEYS = {
    "NasiEggPort",
    "NightHubEggPort",
    "SpeedHubXEggPort",
    "StealAnEgg",
    "EggStealer"
}

for _, key in ipairs(PRIOR_API_KEYS) do
    local oldApi = env and env[key]
    if type(oldApi) == "table" and type(oldApi.Stop) == "function" then
        pcall(oldApi.Stop)
    end
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local running = true
local connections = {}
local cachedCharParts = {}
local promptCache = {}
local slotCache = {}
local lastCharCache = 0
local lastPromptCache = 0
local lastSlotCache = 0
local lastUiPrint = 0
local lastAntiAfk = 0
local busy = false
local usingWabiUi = false

local BASEPART_CLASSES = {
    Part = true,
    MeshPart = true,
    UnionOperation = true,
    WedgePart = true,
    CornerWedgePart = true,
    TrussPart = true,
    SpawnLocation = true
}

local rarityWords = {
    "eternal", "divine", "secret", "ascended", "celestial", "infinity",
    "ancient", "mythic", "lunar", "prismatic", "void"
}

local mutationWords = {
    "rainbow", "sakura", "gold", "golden", "diamond", "emerald", "ruby",
    "cosmic", "galactic", "neon", "shadow", "toxic", "frost", "inferno",
    "magma", "electric", "dark", "outline", "glow", "mutation"
}

local filters = {
    "Total Sweep",
    "Divine & Eternal",
    "Giant & Titan",
    "Mutations & Void",
    "Deep Zones"
}

local state = {
    AutoFarm = false,
    ForFriends = false,
    AutoFeed = false,
    NoClip = false,
    AntiAfk = false,
    Radar = true,
    FilterIndex = 1,
    Speed = 650,
    ReturnX = 535,
    FriendX = 572,
    RouteZ = -364,
    SafeY = 70,
    CruiseY = 155,
    MonsterPos = Vector3.new(545.17, 70.0, -413.42),
    Status = "Idle",
    Target = "None",
    Total = 0,
    LastError = "None",
    RadarTargets = 0
}

local function addConn(conn)
    if conn then
        connections[#connections + 1] = conn
    end
    return conn
end

local function clear(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function say(title, message, duration)
    local text = tostring(message or "")
    local ok = false
    if type(notify) == "function" then
        ok = pcall(notify, tostring(title or SCRIPT_TITLE), text, duration or 2)
    end
    if not ok then
        print("[" .. SCRIPT_TITLE .. "] " .. text)
    end
end

local function readUiBool(name, default)
    if not ui then return default end
    local ok, value = pcall(function()
        return ui.GetValue(ID .. name)
    end)
    if ok and type(value) == "boolean" then
        return value
    end
    return default
end

local function readUiNumber(name, default)
    if not ui then return default end
    local ok, value = pcall(function()
        return ui.GetValue(ID .. name)
    end)
    if ok and tonumber(value) then
        return tonumber(value)
    end
    return default
end

local function readComboIndex(name, options, defaultIndex)
    if not ui then return defaultIndex end
    local ok, value = pcall(function()
        return ui.GetValue(ID .. name)
    end)
    if ok then
        if type(value) == "number" then
            return clamp(value + 1, 1, #options)
        elseif type(value) == "string" then
            for i, option in ipairs(options) do
                if option == value then
                    return i
                end
            end
        end
    end
    return defaultIndex
end

local function syncSettings()
    if usingWabiUi then
        return
    end
    local oldAuto = state.AutoFarm
    state.AutoFarm = readUiBool("auto", state.AutoFarm)
    state.ForFriends = readUiBool("friends", state.ForFriends)
    state.AutoFeed = readUiBool("feed", state.AutoFeed)
    state.NoClip = readUiBool("noclip", state.NoClip or state.AutoFarm)
    state.AntiAfk = readUiBool("antiafk", state.AntiAfk)
    state.Speed = clamp(readUiNumber("speed", state.Speed), 150, 1100)
    state.FilterIndex = readComboIndex("filter", filters, state.FilterIndex)
    if state.AutoFarm and not oldAuto then
        say("Auto Farm", "started", 2)
    elseif oldAuto and not state.AutoFarm then
        say("Auto Farm", "stopped", 2)
    end
end

local function getCharParts()
    local char = LocalPlayer and LocalPlayer.Character
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    local hum = char and char:FindFirstChild("Humanoid")
    return char, root, hum
end

local function releaseKeys()
    pcall(function()
        keyrelease(69)
        keyrelease(0x45)
        keyrelease(113)
        keyrelease(0x51)
        keyrelease(32)
        keyrelease(87)
        keyrelease(65)
        keyrelease(83)
        keyrelease(68)
    end)
end

local function pressKey(code, duration)
    pcall(function()
        keypress(code)
        task.wait(duration or 0.06)
        keyrelease(code)
    end)
end

local function pressE(duration)
    pcall(function()
        keypress(69)
        keypress(0x45)
        task.wait(duration or 0.08)
        keyrelease(69)
        keyrelease(0x45)
    end)
end

local function pressQ(duration)
    pcall(function()
        keypress(113)
        keypress(0x51)
        task.wait(duration or 0.06)
        keyrelease(113)
        keyrelease(0x51)
    end)
end

local function updateCharCache(force)
    local nowTime = tick()
    if not force and nowTime - lastCharCache < 1.5 then
        return
    end
    lastCharCache = nowTime
    clear(cachedCharParts)
    local char = LocalPlayer and LocalPlayer.Character
    if not char then return end
    local ok, list = pcall(function()
        return char:GetDescendants()
    end)
    if not ok then return end
    for _, part in ipairs(list) do
        if part and BASEPART_CLASSES[part.ClassName] then
            cachedCharParts[#cachedCharParts + 1] = part
        end
    end
end

local function applyNoClip()
    updateCharCache(false)
    for _, part in ipairs(cachedCharParts) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = false
            end)
        end
    end
end

local function zeroVelocity()
    local _, root = getCharParts()
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end)
    end
end

local function findPrompt(part)
    if not part then return nil end
    local direct = part:FindFirstChild("CarryAreaEgg") or part:FindFirstChild("ProximityPrompt")
    if direct and direct.ClassName == "ProximityPrompt" then
        return direct
    end
    local ok, children = pcall(function()
        return part:GetChildren()
    end)
    if ok then
        for _, child in ipairs(children) do
            if child and child.ClassName == "ProximityPrompt" then
                return child
            end
        end
    end
    return nil
end

local function updatePromptCache(force)
    local nowTime = tick()
    if not force and nowTime - lastPromptCache < 1.0 then
        return
    end
    lastPromptCache = nowTime
    clear(promptCache)
    local ok, children = pcall(function()
        return Workspace:GetChildren()
    end)
    if not ok then return end
    for _, inst in ipairs(children) do
        if inst and inst.Name == "SmartPromptPart" and BASEPART_CLASSES[inst.ClassName] then
            promptCache[#promptCache + 1] = { part = inst, prompt = findPrompt(inst) }
        end
    end
end

local function nearestPrompt(position, radius)
    updatePromptCache(false)
    local bestPrompt = nil
    local bestDist = radius or 25
    for i = #promptCache, 1, -1 do
        local item = promptCache[i]
        local part = item.part
        if not part or not part.Parent then
            table.remove(promptCache, i)
        else
            local ok, partPos = pcall(function()
                return part.Position
            end)
            if ok and partPos then
                local dist = (partPos - position).Magnitude
                if dist <= bestDist then
                    bestDist = dist
                    bestPrompt = item.prompt or findPrompt(part)
                    item.prompt = bestPrompt
                end
            end
        end
    end
    return bestPrompt
end

local function triggerPrompt(prompt)
    local did = false
    if prompt then
        if type(fireproximityprompt) == "function" then
            pcall(function()
                fireproximityprompt(prompt, 0)
                did = true
            end)
        end
        pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.03)
            prompt:InputHoldEnd()
            did = true
        end)
    end
    pressE(0.06)
    return did
end

local function isHoldingEgg()
    local char = LocalPlayer and LocalPlayer.Character
    if char then
        local ok, children = pcall(function()
            return char:GetChildren()
        end)
        if ok then
            for _, child in ipairs(children) do
                local name = tostring(child and child.Name or "")
                if child.ClassName == "Tool" or name:find("Egg") or name:find("Carry") or name:find("Held") then
                    return true
                end
            end
        end
        local okAttr, holding = pcall(function()
            return char:GetAttribute("HoldingEgg") == true or char:GetAttribute("CarryingEgg") == true
        end)
        if okAttr and holding then
            return true
        end
    end
    return false
end

local function findEggPart(slot)
    if not slot then return nil end
    local part = slot:FindFirstChild("Hitbox") or slot:FindFirstChild("Plane") or slot:FindFirstChild("CustomBoundingBox")
    if part and BASEPART_CLASSES[part.ClassName] then
        return part
    end
    local ok, children = pcall(function()
        return slot:GetChildren()
    end)
    if ok then
        for _, child in ipairs(children) do
            if child and BASEPART_CLASSES[child.ClassName] then
                return child
            end
        end
    end
    local okDesc, descendants = pcall(function()
        return slot:GetDescendants()
    end)
    if okDesc then
        local limit = math.min(#descendants, 80)
        for i = 1, limit do
            local child = descendants[i]
            if child and BASEPART_CLASSES[child.ClassName] then
                return child
            end
        end
    end
    return nil
end

local function hasWord(text, list)
    text = string.lower(tostring(text or ""))
    for _, word in ipairs(list) do
        if text:find(word, 1, true) then
            return true, word
        end
    end
    return false, nil
end

local function inspectEgg(slot)
    if not slot or not slot.Parent then return nil end
    local part = findEggPart(slot)
    if not part then return nil end

    local okPos, position = pcall(function()
        return part.Position
    end)
    if not okPos or not position then return nil end

    local size = Vector3.new(1, 1, 1)
    pcall(function()
        size = part.Size or size
    end)

    local text = tostring(slot.Name or "")
    local ultra = false
    local mutation = false
    local parasite = false
    local tag = nil

    local okDesc, descendants = pcall(function()
        return slot:GetDescendants()
    end)
    if okDesc then
        local limit = math.min(#descendants, 120)
        for i = 1, limit do
            local d = descendants[i]
            local name = tostring(d and d.Name or "")
            local lowerName = string.lower(name)
            text = text .. " " .. name
            if name == "RareAreaEggHighlight" then
                ultra = true
                tag = "Rare Highlight"
            elseif name == "MonsterParasiteVisual" or lowerName:find("parasite", 1, true) then
                parasite = true
            elseif d.ClassName == "Highlight" or d.ClassName == "SelectionBox" then
                mutation = true
            end
        end
    end

    local byUltra, ultraWord = hasWord(text, rarityWords)
    local byMutation, mutationWord = hasWord(text, mutationWords)
    ultra = ultra or byUltra
    mutation = mutation or byMutation
    tag = tag or ultraWord or mutationWord

    local volume = math.abs(size.X * size.Y * size.Z)
    local giant = size.Y >= 4.5 or volume >= 95 or string.lower(text):find("giant", 1, true) ~= nil or string.lower(text):find("titan", 1, true) ~= nil

    local _, root = getCharParts()
    local myPos = root and root.Position or Vector3.new(state.ReturnX, state.SafeY, state.RouteZ)
    local dist = (position - myPos).Magnitude
    local zoneBonus = math.max(0, position.X - 520) * 2
    local score = zoneBonus - dist * 0.1
    if ultra then score = score + 300000 end
    if giant then score = score + 130000 + math.min(50000, volume * 80) end
    if mutation then score = score + 70000 end
    if parasite then score = score + 25000 end

    return {
        slot = slot,
        part = part,
        position = position,
        ultra = ultra,
        giant = giant,
        mutation = mutation,
        parasite = parasite,
        score = score,
        label = tag or (giant and "Giant Egg") or (parasite and "Parasite Egg") or "Egg"
    }
end

local function eligible(egg)
    local idx = state.FilterIndex
    if idx == 1 then
        return true
    elseif idx == 2 then
        return egg.ultra
    elseif idx == 3 then
        return egg.giant or egg.ultra
    elseif idx == 4 then
        return egg.mutation or egg.ultra or egg.giant
    elseif idx == 5 then
        return egg.position.X >= 2000 or egg.ultra
    end
    return true
end

local function updateSlotCache(force)
    local nowTime = tick()
    if not force and nowTime - lastSlotCache < 1.2 then
        return
    end
    lastSlotCache = nowTime
    clear(slotCache)
    local slots = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not slots then return end
    local ok, children = pcall(function()
        return slots:GetChildren()
    end)
    if not ok then return end
    for _, slot in ipairs(children) do
        if slot and slot.ClassName == "Model" then
            local egg = inspectEgg(slot)
            if egg then
                slotCache[#slotCache + 1] = egg
            end
        end
    end
end

local function bestEgg()
    updateSlotCache(false)
    local best = nil
    local bestScore = -math.huge
    for _, egg in ipairs(slotCache) do
        if egg and egg.slot and egg.slot.Parent and egg.part and egg.part.Parent and eligible(egg) then
            if egg.score > bestScore then
                bestScore = egg.score
                best = egg
            end
        end
    end
    return best
end

local RADAR_DOT_LIMIT = 64
local radarReady = false
local radarWarned = false
local radarObjects = {}
local radarDots = {}
local radarBase = {}

local radarColors = {
    Background = Color3.fromRGB(12, 16, 22),
    Border = Color3.fromRGB(78, 101, 128),
    Grid = Color3.fromRGB(46, 62, 82),
    Text = Color3.fromRGB(226, 235, 244),
    Muted = Color3.fromRGB(144, 158, 177),
    Player = Color3.fromRGB(96, 205, 255),
    Normal = Color3.fromRGB(154, 165, 182),
    Ultra = Color3.fromRGB(214, 129, 255),
    Giant = Color3.fromRGB(255, 196, 87),
    Mutation = Color3.fromRGB(70, 230, 205),
    Parasite = Color3.fromRGB(120, 230, 126),
    Target = Color3.fromRGB(255, 245, 165),
    Dim = Color3.fromRGB(82, 93, 112)
}

local function setDraw(obj, prop, value)
    if obj then
        pcall(function()
            obj[prop] = value
        end)
    end
end

local function addDraw(kind, props)
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        return nil
    end
    local ok, obj = pcall(function()
        return Drawing.new(kind)
    end)
    if not ok or not obj then
        return nil
    end
    radarObjects[#radarObjects + 1] = obj
    if props then
        for prop, value in pairs(props) do
            setDraw(obj, prop, value)
        end
    end
    return obj
end

local function ensureRadar()
    if radarReady then
        return true
    end
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
        if not radarWarned then
            radarWarned = true
            print("[" .. SCRIPT_TITLE .. "] radar unavailable: Drawing.new missing")
        end
        return false
    end

    radarBase.bg = addDraw("Square", {
        Filled = true,
        Color = radarColors.Background,
        Transparency = 0.16,
        Rounding = 8,
        ZIndex = 76,
        Visible = false
    })
    radarBase.border = addDraw("Square", {
        Filled = false,
        Thickness = 1,
        Color = radarColors.Border,
        Transparency = 0,
        Rounding = 8,
        ZIndex = 77,
        Visible = false
    })
    radarBase.inner = addDraw("Square", {
        Filled = false,
        Thickness = 1,
        Color = radarColors.Grid,
        Transparency = 0.18,
        ZIndex = 78,
        Visible = false
    })
    radarBase.header = addDraw("Text", {
        Size = 13,
        Font = 2,
        Outline = true,
        Color = radarColors.Text,
        ZIndex = 79,
        Visible = false
    })
    radarBase.sub = addDraw("Text", {
        Size = 11,
        Font = 1,
        Outline = true,
        Color = radarColors.Muted,
        ZIndex = 79,
        Visible = false
    })
    radarBase.footer = addDraw("Text", {
        Size = 11,
        Font = 1,
        Outline = true,
        Color = radarColors.Muted,
        ZIndex = 79,
        Visible = false
    })
    radarBase.player = addDraw("Circle", {
        Radius = 4,
        NumSides = 24,
        Filled = true,
        Color = radarColors.Player,
        Transparency = 0,
        ZIndex = 82,
        Visible = false
    })
    radarBase.targetLine = addDraw("Line", {
        Thickness = 1,
        Color = radarColors.Target,
        Transparency = 0.18,
        ZIndex = 80,
        Visible = false
    })
    radarBase.grid = {}
    for i = 1, 5 do
        radarBase.grid[i] = addDraw("Line", {
            Thickness = 1,
            Color = radarColors.Grid,
            Transparency = 0.3,
            ZIndex = 78,
            Visible = false
        })
    end
    for i = 1, RADAR_DOT_LIMIT do
        radarDots[i] = addDraw("Circle", {
            Radius = 2.5,
            NumSides = 18,
            Filled = true,
            Color = radarColors.Normal,
            Transparency = 0,
            ZIndex = 81,
            Visible = false
        })
    end

    radarReady = radarBase.bg ~= nil
    return radarReady
end

local function hideRadar()
    for _, obj in ipairs(radarObjects) do
        setDraw(obj, "Visible", false)
    end
end

local function removeRadar()
    for _, obj in ipairs(radarObjects) do
        pcall(function()
            obj:Remove()
        end)
    end
    clear(radarObjects)
    clear(radarDots)
    clear(radarBase)
    radarReady = false
end

local function bestEggFromCache()
    local best = nil
    local bestScore = -math.huge
    for _, egg in ipairs(slotCache) do
        if egg and egg.slot and egg.slot.Parent and egg.part and egg.part.Parent and eligible(egg) then
            if egg.score > bestScore then
                bestScore = egg.score
                best = egg
            end
        end
    end
    return best
end

local function colorForEgg(egg, isTarget)
    if isTarget then return radarColors.Target end
    if egg.ultra then return radarColors.Ultra end
    if egg.giant then return radarColors.Giant end
    if egg.mutation then return radarColors.Mutation end
    if egg.parasite then return radarColors.Parasite end
    if not eligible(egg) then return radarColors.Dim end
    return radarColors.Normal
end

local function mapRadarPoint(pos, minX, maxX, minZ, maxZ, x, y, w, h)
    local sx = (pos.X - minX) / math.max(1, maxX - minX)
    local sz = (pos.Z - minZ) / math.max(1, maxZ - minZ)
    sx = clamp(sx, 0, 1)
    sz = clamp(sz, 0, 1)
    return Vector2.new(x + sx * w, y + h - sz * h)
end

local function renderRadar()
    if not running then
        hideRadar()
        return
    end
    if not state.Radar then
        hideRadar()
        return
    end
    if not ensureRadar() then
        return
    end

    local cam = Workspace.CurrentCamera
    local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local panelW = 232
    local panelH = 174
    local panelX = math.max(12, viewport.X - panelW - 18)
    local panelY = 92
    local mapX = panelX + 12
    local mapY = panelY + 34
    local mapW = panelW - 24
    local mapH = panelH - 62

    local _, root = getCharParts()
    local playerPos = root and root.Position or Vector3.new(state.ReturnX, state.SafeY, state.RouteZ)
    local minX = playerPos.X
    local maxX = playerPos.X
    local minZ = playerPos.Z
    local maxZ = playerPos.Z
    local count = 0

    for _, egg in ipairs(slotCache) do
        if egg and egg.slot and egg.slot.Parent and egg.part and egg.part.Parent and egg.position then
            count = count + 1
            local pos = egg.position
            minX = math.min(minX, pos.X)
            maxX = math.max(maxX, pos.X)
            minZ = math.min(minZ, pos.Z)
            maxZ = math.max(maxZ, pos.Z)
        end
    end

    if maxX - minX < 700 then
        local mid = (minX + maxX) * 0.5
        minX = mid - 350
        maxX = mid + 350
    end
    if maxZ - minZ < 150 then
        local mid = (minZ + maxZ) * 0.5
        minZ = mid - 75
        maxZ = mid + 75
    end
    minX = minX - 85
    maxX = maxX + 85
    minZ = minZ - 20
    maxZ = maxZ + 20

    local playerPoint = mapRadarPoint(playerPos, minX, maxX, minZ, maxZ, mapX, mapY, mapW, mapH)
    local best = bestEggFromCache()
    state.RadarTargets = count

    setDraw(radarBase.bg, "Position", Vector2.new(panelX, panelY))
    setDraw(radarBase.bg, "Size", Vector2.new(panelW, panelH))
    setDraw(radarBase.bg, "Visible", true)
    setDraw(radarBase.border, "Position", Vector2.new(panelX, panelY))
    setDraw(radarBase.border, "Size", Vector2.new(panelW, panelH))
    setDraw(radarBase.border, "Visible", true)
    setDraw(radarBase.inner, "Position", Vector2.new(mapX, mapY))
    setDraw(radarBase.inner, "Size", Vector2.new(mapW, mapH))
    setDraw(radarBase.inner, "Visible", true)

    setDraw(radarBase.header, "Text", "EGG RADAR  |  " .. tostring(count))
    setDraw(radarBase.header, "Position", Vector2.new(panelX + 12, panelY + 10))
    setDraw(radarBase.header, "Visible", true)
    setDraw(radarBase.sub, "Text", tostring(filters[state.FilterIndex] or "Total Sweep"))
    setDraw(radarBase.sub, "Position", Vector2.new(panelX + 124, panelY + 12))
    setDraw(radarBase.sub, "Visible", true)

    local gx = radarBase.grid
    if gx then
        local midX = mapX + mapW * 0.5
        local midY = mapY + mapH * 0.5
        setDraw(gx[1], "From", Vector2.new(midX, mapY))
        setDraw(gx[1], "To", Vector2.new(midX, mapY + mapH))
        setDraw(gx[2], "From", Vector2.new(mapX, midY))
        setDraw(gx[2], "To", Vector2.new(mapX + mapW, midY))
        setDraw(gx[3], "From", Vector2.new(mapX + mapW * 0.25, mapY))
        setDraw(gx[3], "To", Vector2.new(mapX + mapW * 0.25, mapY + mapH))
        setDraw(gx[4], "From", Vector2.new(mapX + mapW * 0.75, mapY))
        setDraw(gx[4], "To", Vector2.new(mapX + mapW * 0.75, mapY + mapH))
        setDraw(gx[5], "From", Vector2.new(mapX, mapY + mapH * 0.25))
        setDraw(gx[5], "To", Vector2.new(mapX + mapW, mapY + mapH * 0.25))
        for i = 1, 5 do
            setDraw(gx[i], "Visible", true)
        end
    end

    setDraw(radarBase.player, "Position", playerPoint)
    setDraw(radarBase.player, "Visible", true)

    if best and best.position then
        local targetPoint = mapRadarPoint(best.position, minX, maxX, minZ, maxZ, mapX, mapY, mapW, mapH)
        setDraw(radarBase.targetLine, "From", playerPoint)
        setDraw(radarBase.targetLine, "To", targetPoint)
        setDraw(radarBase.targetLine, "Visible", true)
        local dist = (best.position - playerPos).Magnitude
        setDraw(radarBase.footer, "Text", "target: " .. tostring(best.label) .. "  " .. string.format("%.0f", dist) .. "m")
    else
        setDraw(radarBase.targetLine, "Visible", false)
        setDraw(radarBase.footer, "Text", count > 0 and "no eligible target" or "scanning eggs")
    end
    setDraw(radarBase.footer, "Position", Vector2.new(panelX + 12, panelY + panelH - 20))
    setDraw(radarBase.footer, "Visible", true)

    local used = 0
    for _, egg in ipairs(slotCache) do
        if used >= RADAR_DOT_LIMIT then break end
        if egg and egg.slot and egg.slot.Parent and egg.part and egg.part.Parent and egg.position then
            used = used + 1
            local dot = radarDots[used]
            local isTarget = egg == best
            local pos = mapRadarPoint(egg.position, minX, maxX, minZ, maxZ, mapX, mapY, mapW, mapH)
            setDraw(dot, "Position", pos)
            setDraw(dot, "Radius", isTarget and 4.5 or (egg.giant and 3.7 or 2.6))
            setDraw(dot, "Color", colorForEgg(egg, isTarget))
            setDraw(dot, "Transparency", eligible(egg) and 0 or 0.42)
            setDraw(dot, "Visible", true)
        end
    end
    for i = used + 1, RADAR_DOT_LIMIT do
        setDraw(radarDots[i], "Visible", false)
    end
end

local function moveTo(target, radius, timeout, landing)
    local start = tick()
    radius = radius or 6
    timeout = timeout or 8
    while running and state.AutoFarm do
        local _, root, hum = getCharParts()
        if not root or not hum or (tonumber(hum.Health) or 0) <= 20 then
            state.Status = "Waiting for character"
            return false
        end
        local cur = root.Position
        local delta = target - cur
        local dist = delta.Magnitude
        if dist <= radius then
            zeroVelocity()
            return true
        end
        if tick() - start > timeout then
            zeroVelocity()
            return false
        end
        local speed = state.Speed
        if landing or dist < 45 then
            speed = math.max(80, state.Speed * clamp(dist / 45, 0.15, 1))
        end
        local dir = delta.Unit
        local vy = dir.Y * speed
        if cur.Y <= state.SafeY + 1 and vy < 0 then
            vy = 0
        end
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, vy, dir.Z * speed)
            if cur.Y < state.SafeY - 6 then
                root.CFrame = CFrame.new(cur.X, state.SafeY + 2, cur.Z)
            end
        end)
        task.wait(0.05)
    end
    zeroVelocity()
    return false
end

local function routeTo(position, land)
    local _, root = getCharParts()
    if not root then return false end
    local current = root.Position
    local routeZ = clamp(current.Z, -460, -260)
    if math.abs(routeZ - state.RouteZ) > 120 then
        routeZ = state.RouteZ
    end
    local skyY = math.max(state.CruiseY, state.SafeY + 55)
    local p1 = Vector3.new(current.X, skyY, routeZ)
    local p2 = Vector3.new(position.X, skyY, position.Z)
    if not moveTo(p1, 10, 3, false) then return false end
    if not moveTo(p2, 16, 8, false) then return false end
    if land then
        return moveTo(Vector3.new(position.X, math.max(state.SafeY + 1, position.Y + 2), position.Z), 6, 4, true)
    end
    return true
end

local function returnPosition()
    local _, root = getCharParts()
    local z = root and clamp(root.Position.Z, -460, -260) or state.RouteZ
    if state.ForFriends then
        return Vector3.new(state.FriendX, state.SafeY + 2, z)
    end
    return Vector3.new(state.ReturnX, state.SafeY + 2, z)
end

local function grabEgg(egg)
    if not egg then return false end
    routeTo(egg.position, true)
    local start = tick()
    while running and state.AutoFarm and tick() - start < 1.4 do
        local _, root = getCharParts()
        if root then
            triggerPrompt(nearestPrompt(root.Position, 28))
        else
            pressE(0.08)
        end
        if isHoldingEgg() or not egg.slot.Parent then
            return true
        end
        task.wait(0.12)
    end
    return isHoldingEgg() or not egg.slot.Parent
end

local function depositEgg(egg)
    if egg and egg.parasite and state.AutoFeed then
        state.Status = "Feed monster"
        routeTo(state.MonsterPos, true)
        pressE(0.8)
        return
    end
    if state.ForFriends then
        state.Status = "Friend drop"
    else
        state.Status = "Return base"
    end
    routeTo(returnPosition(), false)
    task.wait(0.1)
    pressQ(0.08)
end

local function pulseAntiAfk()
    if not state.AntiAfk then return end
    local nowTime = tick()
    if nowTime - lastAntiAfk < 30 then return end
    lastAntiAfk = nowTime
    pcall(function()
        local vu = game:GetService("VirtualUser")
        local cam = Workspace.CurrentCamera
        if vu and vu.CaptureController and vu.ClickButton2 then
            vu:CaptureController()
            vu:ClickButton2(Vector2.new(0, 0), cam and cam.CFrame or CFrame.new())
        end
    end)
end

local function scanOnce()
    updateSlotCache(true)
    local egg = bestEgg()
    if egg then
        state.Target = egg.label
        state.Status = "Target found"
        print("[" .. SCRIPT_TITLE .. "] target " .. tostring(egg.label) .. " x=" .. string.format("%.1f", egg.position.X) .. " score=" .. string.format("%.1f", egg.score))
    else
        state.Target = "None"
        state.Status = "No egg"
        print("[" .. SCRIPT_TITLE .. "] no eligible egg for filter " .. tostring(filters[state.FilterIndex]))
    end
    return egg
end

local function mainLoop()
    while running do
        syncSettings()
        pulseAntiAfk()
        if not state.AutoFarm then
            state.Status = "Idle"
            task.wait(0.2)
        elseif busy then
            task.wait(0.1)
        else
            busy = true
            local ok, err = pcall(function()
                local _, root, hum = getCharParts()
                if not root or not hum or (tonumber(hum.Health) or 0) <= 20 then
                    state.Status = "Waiting for character"
                    task.wait(0.8)
                    return
                end
                local egg = bestEgg()
                if not egg then
                    updateSlotCache(true)
                    egg = bestEgg()
                end
                if egg then
                    state.Target = egg.label
                    state.Status = "Grab " .. egg.label
                    if grabEgg(egg) then
                        depositEgg(egg)
                        state.Total = state.Total + 1
                        state.Status = "Done"
                        updateSlotCache(true)
                    else
                        state.Status = "Grab retry"
                    end
                else
                    state.Target = "None"
                    state.Status = "Scanning"
                    local home = returnPosition()
                    if (root.Position - home).Magnitude > 45 then
                        routeTo(home, false)
                    else
                        zeroVelocity()
                        task.wait(0.4)
                    end
                end
            end)
            if not ok then
                state.LastError = tostring(err)
                state.Status = "Error"
                print("[" .. SCRIPT_TITLE .. "] error " .. state.LastError)
                task.wait(0.8)
            end
            busy = false
            task.wait(0.1)
        end
    end
end

local function heartbeat()
    if not running then return end
    if state.NoClip or state.AutoFarm then
        applyNoClip()
    end
end

local wabiLibrary = nil
local wabiWindow = nil
local controls = {}

local function stop()
    running = false
    state.AutoFarm = false
    releaseKeys()
    zeroVelocity()
    for _, conn in ipairs(connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    clear(connections)
    if ui then
        pcall(function()
            ui.RemoveTab(TAB_NAME)
            ui.RemoveTab(TAB_NAME)
        end)
    end
    if wabiLibrary and type(wabiLibrary["De" .. "stroy"]) == "function" then
        pcall(function()
            wabiLibrary["De" .. "stroy"](wabiLibrary)
        end)
    end
    print("[" .. SCRIPT_TITLE .. "] stopped")
end

local api = {
    State = state,
    Stop = stop,
    Scan = scanOnce,
    Diag = function()
        return string.format("script=%s running=%s auto=%s radar=%s filter=%s slots=%d radarTargets=%d status=%s target=%s total=%d err=%s", SCRIPT_TITLE, tostring(running), tostring(state.AutoFarm), tostring(state.Radar), tostring(filters[state.FilterIndex] or state.FilterIndex), #slotCache, tonumber(state.RadarTargets) or 0, tostring(state.Status), tostring(state.Target), tonumber(state.Total) or 0, tostring(state.LastError))
    end
}

env[API_KEY] = api
env.StealAnEgg = api

local function getGlobal(name)
    if env and env[name] ~= nil then return env[name] end
    if _G and _G[name] ~= nil then return _G[name] end
    return nil
end

local function fetchText(url)
    if type(httpget) == "function" then
        local ok, data = pcall(function()
            return httpget(url)
        end)
        if ok and type(data) == "string" and #data > 0 then
            return data, nil
        end
    end
    local ok, data = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(data) == "string" and #data > 0 then
        return data, nil
    end
    return nil, tostring(data)
end

local function setFilterValue(value)
    if type(value) == "number" then
        state.FilterIndex = clamp(value + 1, 1, #filters)
        return
    end
    local text = tostring(value or "")
    for i, option in ipairs(filters) do
        if option == text then
            state.FilterIndex = i
            return
        end
    end
end

local function setAuto(value)
    state.AutoFarm = value == true
    if not state.AutoFarm then
        releaseKeys()
        zeroVelocity()
    end
    say("Auto Farm", state.AutoFarm and "started" or "stopped", 2)
end

local function loadWabiSabi()
    local lib = getGlobal("WabiSabi")
    if type(lib) == "table" and type(lib.CreateWindow) == "function" then
        return lib, nil
    end

    local source, fetchErr = fetchText("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua")
    if not source then
        return nil, "download failed: " .. tostring(fetchErr)
    end

    local fn, compileErr = loadstring(source)
    if type(fn) ~= "function" then
        return nil, "compile failed: " .. tostring(compileErr)
    end

    local ok, result = pcall(fn)
    if ok and type(result) == "table" and type(result.CreateWindow) == "function" then
        return result, nil
    end

    lib = getGlobal("WabiSabi")
    if type(lib) == "table" and type(lib.CreateWindow) == "function" then
        return lib, nil
    end

    return nil, "start failed: " .. tostring(result)
end

local function setupWabiUi()
    local lib, loadErr = loadWabiSabi()
    if not lib then
        print("[" .. SCRIPT_TITLE .. "] UI failed - " .. tostring(loadErr))
        print("[" .. SCRIPT_TITLE .. "] hotkeys: K auto farm, J scan, API getfenv()." .. API_KEY)
        return false
    end

    wabiLibrary = lib
    usingWabiUi = true
    local ok, err = pcall(function()
        wabiWindow = lib:CreateWindow({
            Title = SCRIPT_TITLE,
            SubTitle = "Steal An Egg",
            Size = Vector2.new(560, 430),
            Resize = true,
            MinimizeKey = "RightControl",
        })

        local farmTab = wabiWindow:AddTab({ Title = "Farm" })
        local farm = farmTab:AddSection("Auto Farm")
        controls.auto = farm:AddToggle({
            Id = ID .. "auto",
            Title = "Auto Farm",
            Default = false,
            Callback = function(value)
                setAuto(value)
            end,
        })
        controls.friends = farm:AddToggle({
            Id = ID .. "friends",
            Title = "For Friends",
            Default = false,
            Callback = function(value)
                state.ForFriends = value == true
            end,
        })
        controls.feed = farm:AddToggle({
            Id = ID .. "feed",
            Title = "Auto Feed Monster",
            Default = false,
            Callback = function(value)
                state.AutoFeed = value == true
            end,
        })
        farm:AddButton({
            Title = "Scan Once",
            Description = "Print best target to Matcha logs",
            Callback = function()
                scanOnce()
            end,
        })

        local target = farmTab:AddSection("Target")
        controls.filter = target:AddDropdown({
            Id = ID .. "filter",
            Title = "Target Filter",
            Values = filters,
            Options = filters,
            Default = filters[state.FilterIndex],
            Callback = function(value)
                setFilterValue(value)
            end,
        })
        controls.speed = target:AddSlider({
            Id = ID .. "speed",
            Title = "Movement Speed",
            Min = 150,
            Max = 1100,
            Default = state.Speed,
            Rounding = 0,
            Callback = function(value)
                state.Speed = clamp(value, 150, 1100)
            end,
        })

        local miscTab = wabiWindow:AddTab({ Title = "Misc" })
        local misc = miscTab:AddSection("Runtime")
        controls.noclip = misc:AddToggle({
            Id = ID .. "noclip",
            Title = "NoClip",
            Default = false,
            Callback = function(value)
                state.NoClip = value == true
            end,
        })
        controls.antiafk = misc:AddToggle({
            Id = ID .. "antiafk",
            Title = "Anti Afk",
            Default = false,
            Callback = function(value)
                state.AntiAfk = value == true
            end,
        })
        controls.radar = misc:AddToggle({
            Id = ID .. "radar",
            Title = "Egg Radar",
            Default = true,
            Callback = function(value)
                state.Radar = value == true
                if not state.Radar then
                    hideRadar()
                end
            end,
        })
        misc:AddButton({
            Title = "Print Status",
            Description = "Shows current script state in logs",
            Callback = function()
                print("[" .. SCRIPT_TITLE .. "] " .. api.Diag())
            end,
        })
        misc:AddButton({
            Title = "Stop Script",
            Description = "Stops movement and loops",
            Callback = function()
                stop()
            end,
        })

        if type(lib.Notify) == "function" then
            lib:Notify({ Title = SCRIPT_TITLE, Content = "Loaded. Toggle Auto Farm to start.", Duration = 4 })
        end
    end)

    if not ok then
        print("[" .. SCRIPT_TITLE .. "] UI error - " .. tostring(err))
        print("[" .. SCRIPT_TITLE .. "] hotkeys: K auto farm, J scan, API getfenv()." .. API_KEY)
        return false
    end

    print("[" .. SCRIPT_TITLE .. "] UI ready / RightControl toggles menu")
    return true
end

setupWabiUi()

addConn(RunService.Heartbeat:Connect(heartbeat))
addConn(RunService.RenderStepped:Connect(renderRadar))
addConn(UserInputService.InputBegan:Connect(function(input)
    if not running or type(input) ~= "table" then return end
    local key = input.KeyCode
    if key == 74 or key == 106 then
        scanOnce()
    elseif key == 75 or key == 107 then
        local value = not state.AutoFarm
        if controls.auto and type(controls.auto.SetValue) == "function" then
            pcall(function()
                controls.auto:SetValue(value)
            end)
        else
            setAuto(value)
        end
    elseif key == 82 or key == 114 then
        local value = not state.Radar
        state.Radar = value
        if controls.radar and type(controls.radar.SetValue) == "function" then
            pcall(function()
                controls.radar:SetValue(value)
            end)
        end
        if not state.Radar then
            hideRadar()
        end
        say("Egg Radar", state.Radar and "shown" or "hidden", 2)
    end
end))

pcall(function()
    if LocalPlayer.Idled then
        addConn(LocalPlayer.Idled:Connect(function()
            pulseAntiAfk()
        end))
    end
end)

task.spawn(mainLoop)
task.spawn(function()
    while running do
        updatePromptCache(true)
        updateCharCache(true)
        if state.AutoFarm then
            updateSlotCache(true)
        end
        task.wait(1.0)
    end
end)

print("[" .. SCRIPT_TITLE .. "] loaded / getfenv()." .. API_KEY .. ".Stop() to stop")
