--[[
    Crystal Auto-Farm & ESP Hub
    Features: Filterable ESP, Tween Auto Farm, Auto Sell, Grab Radius
]]

--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// Variables
local LocalPlayer = Players.LocalPlayer

-- Dynamic getters to prevent infinite yielding that stops the GUI from loading
local function getRealStats()
    local pd = LocalPlayer:FindFirstChild("PlayerData")
    return pd and pd:FindFirstChild("RealStats")
end

local function getCrystalsFolder()
    local things = Workspace:FindFirstChild("Things")
    return things and things:FindFirstChild("Crystals")
end

local function getDroppedCrystalsFolder()
    return Workspace:FindFirstChild("DroppedCrystals")
end

local function getSellProx()
    local things = Workspace:FindFirstChild("Things")
    return things and things:FindFirstChild("SellProx")
end

--// Configuration / State
local _G = {
    AutoFarm = false,
    AutoSell = false,
    ESP = false,
    GrabRadiusEnabled = false,
    GrabRadius = 20,
    TweenSpeed = 30, -- Studs per second
    MaxWeight = 100, -- Fallback value
    
    -- Filters
    Filters = {
        UseFilters = false,
        CrystalName = "",
        MinSizeClass = 0,
        MinWeightKg = 0,
        MinTier = 0
    }
}

--// Load Orion GUI Library Safely
local OrionLib

local success, result = pcall(function()
    -- Attempt 1: Official Source
    return loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()
end)

if success and result then
    OrionLib = result
    print("[Crystal Hub]: Loaded Orion from Official Source.")
else
    warn("[Crystal Hub]: Official Orion source failed. Trying backup mirror... Error: " .. tostring(result))
    
    local backupSuccess, backupResult = pcall(function()
        -- Attempt 2: Backup Mirror (Mobile & Desktop friendly mirror)
        return loadstring(game:HttpGet('https://raw.githubusercontent.com/thanhdat4461/OrionMoblie/main/source'))()
    end)
    
    if backupSuccess and backupResult then
        OrionLib = backupResult
        print("[Crystal Hub]: Loaded Orion from Backup Source.")
    else
        error("[Crystal Hub]: Both GUI sources failed to load. Your executor might not support HttpGet, or your internet/ISP is blocking GitHub raw links.")
        return -- Stop the script completely
    end
end

local Window = OrionLib:MakeWindow({Name = "Crystal Mining Hub", HidePremium = false, SaveConfig = true, ConfigFolder = "CrystalHubConfig"})

--// Utility Functions
local function getHRP()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        return character.HumanoidRootPart
    end
    return nil
end

local function firePrompt(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then
        if fireproximityprompt then
            -- Used the single argument safely. Some executors error with the extra arguments.
            fireproximityprompt(prompt)
        else
            -- Fallback if executor doesn't support fireproximityprompt natively
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end
    end
end

-- Checks if a crystal passes the current GUI filters
local function passesFilter(crystal)
    if not _G.Filters.UseFilters then return true end
    
    local nameAttr = crystal:GetAttribute("CrystalName") or ""
    local sizeAttr = crystal:GetAttribute("sizeclass") or 0
    local weightAttr = crystal:GetAttribute("weightkg") or 0
    local tierAttr = crystal:GetAttribute("tier") or 0

    if _G.Filters.CrystalName ~= "" and not string.find(string.lower(nameAttr), string.lower(_G.Filters.CrystalName)) then
        return false
    end
    if tonumber(sizeAttr) < _G.Filters.MinSizeClass then return false end
    if tonumber(weightAttr) < _G.Filters.MinWeightKg then return false end
    if tonumber(tierAttr) < _G.Filters.MinTier then return false end

    return true
end

-- Tween to a specific CFrame
local function tweenTo(targetCFrame)
    local hrp = getHRP()
    if not hrp then return end
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local timeToTween = distance / _G.TweenSpeed
    
    local tweenInfo = TweenInfo.new(timeToTween, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Wait()
end

-- Checks if the bag is full (Based on Player stats)
local function isBagFull()
    local RealStats = getRealStats()
    if not RealStats then return false end
    
    -- Depending on how the game structures it, it might compare CurrentWeight to CarryWeight
    -- Assuming a generic structure based on provided RealStats:
    local maxWeight = RealStats:FindFirstChild("CarryWeight") and RealStats.CarryWeight.Value or _G.MaxWeight
    
    -- NOTE: "CurrentWeight" was not in your provided stats list.
    -- If your auto-sell doesn't work, update "CurrentWeight" below to the correct path!
    local currentWeight = RealStats:FindFirstChild("CurrentWeight") and RealStats.CurrentWeight.Value or 0 
    
    if currentWeight >= maxWeight and maxWeight > 0 then
        return true
    end
    return false
end

-- Sell logic
local function performSell()
    local SellProx = getSellProx()
    if not SellProx then return end
    
    local prompt = SellProx:FindFirstChildWhichIsA("ProximityPrompt", true) -- True ensures recursive search
    if prompt then
        -- Safely grab CFrame whether SellProx is a Model or a Part
        local targetCFrame = SellProx:IsA("Model") and SellProx:GetPivot() or SellProx.CFrame
        tweenTo(targetCFrame * CFrame.new(0, 0, 3)) -- Tween slightly in front of the sell box
        
        task.wait(0.2)
        firePrompt(prompt)
        
        -- Handle the dialogue GUI (Press '1' to "Sell all crystals")
        task.wait(0.5)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        task.wait(1)
    end
end

-- Find nearest valid crystal
local function getNearestCrystal()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local nearestDist = math.huge
    local nearestCrystal = nil
    
    local function checkFolder(folder)
        if not folder then return end
        for _, crystal in ipairs(folder:GetChildren()) do
            if crystal:IsA("Model") and crystal.PrimaryPart then
                crystal = crystal.PrimaryPart
            end
            
            if crystal:IsA("BasePart") and crystal:FindFirstChildOfClass("ProximityPrompt") then
                if passesFilter(crystal) then
                    local dist = (hrp.Position - crystal.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestCrystal = crystal
                    end
                end
            end
        end
    end
    
    checkFolder(getCrystalsFolder())
    checkFolder(getDroppedCrystalsFolder())
    
    return nearestCrystal
end

--// Main Loops

-- Noclip Loop (Prevents getting stuck while tweening)
RunService.Stepped:Connect(function()
    if _G.AutoFarm then
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- Auto Farm Loop
task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoFarm then
            if _G.AutoSell and isBagFull() then
                performSell()
            else
                local target = getNearestCrystal()
                if target and target.Parent then
                    tweenTo(target.CFrame)
                    
                    -- Check if target is still valid after tweening (in case someone else mined it)
                    if target and target.Parent then
                        local prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt then
                            firePrompt(prompt)
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end
end)

-- Auto Grab Radius Loop
task.spawn(function()
    while task.wait(0.1) do
        if _G.GrabRadiusEnabled then
            local hrp = getHRP()
            if hrp then
                local function grabFrom(folder)
                    if not folder then return end
                    for _, crystal in ipairs(folder:GetChildren()) do
                        local part = crystal:IsA("Model") and crystal.PrimaryPart or crystal
                        if part and part:IsA("BasePart") then
                            local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and passesFilter(part) then
                                local dist = (hrp.Position - part.Position).Magnitude
                                if dist <= _G.GrabRadius then
                                    firePrompt(prompt)
                                end
                            end
                        end
                    end
                end
                grabFrom(getCrystalsFolder())
                grabFrom(getDroppedCrystalsFolder())
            end
        end
    end
end)

-- ESP Loop
local ESPObjects = {}
task.spawn(function()
    while task.wait(0.5) do
        if not _G.ESP then
            -- Clean up ESP
            for _, gui in pairs(ESPObjects) do
                if gui then gui:Destroy() end
            end
            table.clear(ESPObjects)
            continue
        end
        
        local function createESP(folder)
            if not folder then return end
            for _, crystal in ipairs(folder:GetChildren()) do
                local part = crystal:IsA("Model") and crystal.PrimaryPart or crystal
                if part and part:IsA("BasePart") then
                    if passesFilter(part) then
                        if not ESPObjects[part] then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "CrystalESP"
                            billboard.AlwaysOnTop = true
                            billboard.Size = UDim2.new(0, 100, 0, 50)
                            billboard.StudsOffset = Vector3.new(0, 2, 0)
                            billboard.Adornee = part
                            
                            local textLabel = Instance.new("TextLabel", billboard)
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.TextScaled = true
                            textLabel.TextColor3 = Color3.new(0, 1, 1)
                            textLabel.TextStrokeTransparency = 0
                            
                            local name = part:GetAttribute("CrystalName") or "Crystal"
                            local tier = part:GetAttribute("tier") or "?"
                            textLabel.Text = string.format("%s\n[Tier %s]", name, tostring(tier))
                            
                            -- Safe GUI Parent fallback
                            local safeParent = (gethui and gethui()) or game:GetService("CoreGui")
                            if not safeParent then safeParent = LocalPlayer:WaitForChild("PlayerGui") end
                            billboard.Parent = safeParent
                            
                            ESPObjects[part] = billboard
                        end
                    else
                        if ESPObjects[part] then
                            ESPObjects[part]:Destroy()
                            ESPObjects[part] = nil
                        end
                    end
                end
            end
        end
        
        createESP(getCrystalsFolder())
        createESP(getDroppedCrystalsFolder())
        
        -- Clean up nil objects
        for part, gui in pairs(ESPObjects) do
            if not part or not part.Parent then
                gui:Destroy()
                ESPObjects[part] = nil
            end
        end
    end
end)


--// GUI Construction
local MainTab = Window:MakeTab({Name = "Main", Icon = "rbxassetid://4483345998", PremiumOnly = false})

MainTab:AddToggle({
    Name = "Auto Farm Crystals",
    Default = false,
    Callback = function(Value)
        _G.AutoFarm = Value
    end
})

MainTab:AddToggle({
    Name = "Auto Sell (When Bag Full)",
    Default = false,
    Callback = function(Value)
        _G.AutoSell = Value
    end
})

MainTab:AddSlider({
    Name = "Tween Speed",
    Min = 10,
    Max = 100,
    Default = 30,
    Color = Color3.fromRGB(255,255,255),
    Increment = 1,
    ValueName = "Studs/s",
    Callback = function(Value)
        _G.TweenSpeed = Value
    end
})

MainTab:AddToggle({
    Name = "Enable Aura Grab (Radius)",
    Default = false,
    Callback = function(Value)
        _G.GrabRadiusEnabled = Value
    end
})

MainTab:AddSlider({
    Name = "Aura Grab Radius",
    Min = 5,
    Max = 50,
    Default = 20,
    Color = Color3.fromRGB(0,255,0),
    Increment = 1,
    ValueName = "Studs",
    Callback = function(Value)
        _G.GrabRadius = Value
    end
})

local FilterTab = Window:MakeTab({Name = "Filters & ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false})

FilterTab:AddToggle({
    Name = "Enable ESP",
    Default = false,
    Callback = function(Value)
        _G.ESP = Value
    end
})

FilterTab:AddToggle({
    Name = "Apply Filters to Actions",
    Default = false,
    Callback = function(Value)
        _G.Filters.UseFilters = Value
    end
})

FilterTab:AddTextbox({
    Name = "Crystal Name Filter",
    Default = "",
    TextDisappear = false,
    Callback = function(Value)
        _G.Filters.CrystalName = Value
    end
})

FilterTab:AddSlider({
    Name = "Minimum Tier",
    Min = 0,
    Max = 10,
    Default = 0,
    Color = Color3.fromRGB(255,0,0),
    Increment = 1,
    ValueName = "Tier",
    Callback = function(Value)
        _G.Filters.MinTier = Value
    end
})

FilterTab:AddSlider({
    Name = "Minimum Size Class",
    Min = 0,
    Max = 10,
    Default = 0,
    Color = Color3.fromRGB(255,255,0),
    Increment = 1,
    ValueName = "Size",
    Callback = function(Value)
        _G.Filters.MinSizeClass = Value
    end
})

FilterTab:AddSlider({
    Name = "Minimum Weight (kg)",
    Min = 0,
    Max = 1000,
    Default = 0,
    Color = Color3.fromRGB(0,0,255),
    Increment = 5,
    ValueName = "kg",
    Callback = function(Value)
        _G.Filters.MinWeightKg = Value
    end
})

local StatsTab = Window:MakeTab({Name = "Live Stats", Icon = "rbxassetid://4483345998", PremiumOnly = false})
local CashLabel = StatsTab:AddLabel("Cash: Loading...")
local CarryLabel = StatsTab:AddLabel("Carry Weight: Loading...")

-- Update Stats GUI loop
task.spawn(function()
    while task.wait(1) do
        local RealStats = getRealStats()
        if RealStats then
            if RealStats:FindFirstChild("Cash") then
                CashLabel:Set("Cash: $" .. tostring(RealStats.Cash.Value))
            end
            if RealStats:FindFirstChild("CarryWeight") then
                CarryLabel:Set("Carry Wght Capacity: " .. tostring(RealStats.CarryWeight.Value))
            end
        end
    end
end)

OrionLib:Init()
