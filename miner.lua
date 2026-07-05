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
local PlayerData = LocalPlayer:WaitForChild("PlayerData")
local RealStats = PlayerData:WaitForChild("RealStats")

local Things = Workspace:WaitForChild("Things")
local CrystalsFolder = Things:WaitForChild("Crystals")
local DroppedCrystals = Workspace:WaitForChild("DroppedCrystals")
local SellProx = Things:WaitForChild("SellProx")

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

--// Load Orion GUI Library
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/shlexware/Orion/main/source')))()
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
            fireproximityprompt(prompt, 1, true)
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
    -- Depending on how the game structures it, it might compare CurrentWeight to CarryWeight
    -- Assuming a generic structure based on provided RealStats:
    local maxWeight = RealStats:FindFirstChild("CarryWeight") and RealStats.CarryWeight.Value or _G.MaxWeight
    -- If there's a specific current weight stat, check it here. Otherwise, we rely on the Auto Sell button toggle logic.
    -- Assuming a "CurrentWeight" exists; update the name if it's different.
    local currentWeight = RealStats:FindFirstChild("CurrentWeight") and RealStats.CurrentWeight.Value or 0 
    
    if currentWeight >= maxWeight and maxWeight > 0 then
        return true
    end
    return false
end

-- Sell logic
local function performSell()
    local prompt = SellProx:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        tweenTo(SellProx.CFrame * CFrame.new(0, 0, 3)) -- Tween slightly in front of the sell box
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
    
    checkFolder(CrystalsFolder)
    checkFolder(DroppedCrystals)
    
    return nearestCrystal
end

--// Main Loops
-- Auto Farm Loop
task.spawn(function()
    while task.wait(0.1) do
        if _G.AutoFarm then
            if _G.AutoSell and isBagFull() then
                performSell()
            else
                local target = getNearestCrystal()
                if target then
                    tweenTo(target.CFrame)
                    local prompt = target:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then
                        firePrompt(prompt)
                        task.wait(0.2)
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
                grabFrom(CrystalsFolder)
                grabFrom(DroppedCrystals)
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
                            
                            billboard.Parent = game.CoreGui
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
        
        createESP(CrystalsFolder)
        createESP(DroppedCrystals)
        
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
        if RealStats:FindFirstChild("Cash") then
            CashLabel:Set("Cash: $" .. tostring(RealStats.Cash.Value))
        end
        if RealStats:FindFirstChild("CarryWeight") then
            CarryLabel:Set("Carry Wght Capacity: " .. tostring(RealStats.CarryWeight.Value))
        end
    end
end)

OrionLib:Init()
