--!strict
-- Matcha runtime cleanup for Steal An Egg port attempts.
-- Upload this as remove.lua and run with loadstring(httpget(raw_url))().

local env = getfenv()
local roots = {}
local seenRoots = {}

local function addRoot(root)
    if type(root) == "table" and not seenRoots[root] then
        seenRoots[root] = true
        roots[#roots + 1] = root
    end
end

addRoot(env)
addRoot(_G)
addRoot(shared)
pcall(function()
    if type(getgenv) == "function" then
        addRoot(getgenv())
    end
end)

local stopped = {}
local function note(name)
    stopped[#stopped + 1] = tostring(name)
end

local function safeCall(fn, self, label)
    if type(fn) ~= "function" then return false end
    local ok
    if self ~= nil then
        ok = pcall(function()
            fn(self)
        end)
    else
        ok = pcall(fn)
    end
    if ok then note(label) end
    return ok
end

local function stopObject(obj, label)
    if type(obj) ~= "table" then return end
    pcall(function()
        if type(obj.State) == "table" then
            obj.State.AutoFarm = false
            obj.State.Enabled = false
            obj.State.Running = false
            obj.State.NoClip = false
            obj.State.Ragdoll = false
        end
        obj.running = false
        obj.Running = false
        obj.Enabled = false
    end)
    safeCall(obj.Stop, obj, label .. ":Stop")
    safeCall(obj.stop, obj, label .. ":stop")
    safeCall(obj.Cleanup, obj, label .. ":Cleanup")
    safeCall(obj.cleanup, obj, label .. ":cleanup")
    safeCall(obj["De" .. "stroy"], obj, label .. ":destroy")
    safeCall(obj.Unload, obj, label .. ":Unload")
    safeCall(obj.unload, obj, label .. ":unload")
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
        keyrelease(16)
    end)
end

local function zeroVelocity()
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local char = player and player.Character
        local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
        if root then
            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            root.Velocity = Vector3.new(0, 0, 0)
        end
    end)
end

local function removeUiTabs(root)
    local ui = root and root.UI
    if type(ui) ~= "table" or type(ui.RemoveTab) ~= "function" then return end
    local tabs = {
        "Nasi Egg",
        "NightHub Egg",
        "SpeedHubX Egg",
        "Steal An Egg",
        "Steal an egg",
        "EggStealer",
        "Egg Stealer",
        "Matcha Autobot"
    }
    for _, name in ipairs(tabs) do
        pcall(function()
            ui.RemoveTab(name)
            ui.RemoveTab(name)
        end)
    end
end

local apiKeys = {
    "StealAnEgg",
    "NasiEggPort",
    "NightHubEggPort",
    "SpeedHubXEggPort",
    "EggStealer",
    "Nasi",
    "NightHub",
    "SpeedHubX",
    "CleanSuiteAPI"
}

local funcKeys = {
    "CleanSuite",
    "EggStealerCleanup",
    "StealAnEggCleanup",
    "NasiCleanup",
    "NightHubCleanup",
    "SpeedHubXCleanup"
}

for _, root in ipairs(roots) do
    for _, key in ipairs(funcKeys) do
        safeCall(root[key], nil, key)
    end
end

for _, root in ipairs(roots) do
    if type(root.__nonui) == "table" then
        stopObject(root.__nonui, "__nonui")
        safeCall(root.__nonui.stop, nil, "__nonui.stop")
    end
    if type(root.NonUI) == "table" then
        stopObject(root.NonUI, "NonUI")
    end
    if type(root.WabiSabi) == "table" then
        stopObject(root.WabiSabi, "WabiSabi")
    end
    if type(root.__WabiSabi) == "table" then
        stopObject(root.__WabiSabi, "__WabiSabi")
        safeCall(root.__WabiSabi._RemoveAll, root.__WabiSabi, "__WabiSabi:_RemoveAll")
    end
end

for _, root in ipairs(roots) do
    for _, key in ipairs(apiKeys) do
        stopObject(root[key], key)
    end
end

for _, root in ipairs(roots) do
    removeUiTabs(root)
end

releaseKeys()
zeroVelocity()

for _, root in ipairs(roots) do
    for _, key in ipairs(apiKeys) do
        pcall(function() root[key] = nil end)
    end
    for _, key in ipairs(funcKeys) do
        pcall(function() root[key] = nil end)
    end
    pcall(function() root.__nonui = nil end)
    pcall(function() root.NonUI = nil end)
    pcall(function() root.__WabiSabi = nil end)
    pcall(function() root.__WabiSabiToken = nil end)
    pcall(function() root.WabiSabi = nil end)
end

print("[remove] cleanup ran; stopped=" .. tostring(#stopped) .. (#stopped > 0 and (" " .. table.concat(stopped, ", ")) or ""))
