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

--// Native GUI Construction
local safeParent = (gethui and gethui()) or game:GetService("CoreGui")
if not pcall(function() local _ = safeParent.Name end) then safeParent = LocalPlayer:WaitForChild("PlayerGui") end

-- Clean up old GUI if exists
if safeParent:FindFirstChild("CrystalNativeHub") then
    safeParent.CrystalNativeHub:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CrystalNativeHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = safeParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 420)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Built-in dragging
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Crystal Mining Hub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local Container = Instance.new("ScrollingFrame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 40)
Container.BackgroundTransparency = 1
Container.ScrollBarThickness = 4
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.Parent = Container

local function createToggle(name, defaultState, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 65)
    btn.Text = name .. ": " .. (defaultState and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.Parent = Container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local state = defaultState
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 65)
        btn.Text = name .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
end

local function createInput(name, defaultValue, isNumber, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundTransparency = 1
    frame.Parent = Container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.4, 0, 1, 0)
    box.Position = UDim2.new(0.6, 0, 0, 0)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Text = tostring(defaultValue)
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = frame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box
    
    box.FocusLost:Connect(function()
        local val = box.Text
        if isNumber then
            val = tonumber(val) or defaultValue
            box.Text = tostring(val)
        end
        callback(val)
    end)
end

local function createLabel(name)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Color3.fromRGB(150, 200, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.Parent = Container
    return lbl
end

-- Populate GUI Elements
createLabel("--- MAIN CONTROLS ---")
createToggle("Auto Farm Crystals", _G.AutoFarm, function(v) _G.AutoFarm = v end)
createToggle("Auto Sell (When Bag Full)", _G.AutoSell, function(v) _G.AutoSell = v end)
createInput("Tween Speed", _G.TweenSpeed, true, function(v) _G.TweenSpeed = v end)

createLabel("--- AURA GRAB ---")
createToggle("Enable Aura Grab", _G.GrabRadiusEnabled, function(v) _G.GrabRadiusEnabled = v end)
createInput("Grab Radius", _G.GrabRadius, true, function(v) _G.GrabRadius = v end)

createLabel("--- FILTERS & ESP ---")
createToggle("Enable ESP", _G.ESP, function(v) _G.ESP = v end)
createToggle("Apply Filters", _G.Filters.UseFilters, function(v) _G.Filters.UseFilters = v end)
createInput("Name Filter", _G.Filters.CrystalName, false, function(v) _G.Filters.CrystalName = v end)
createInput("Min Tier", _G.Filters.MinTier, true, function(v) _G.Filters.MinTier = v end)
createInput("Min Size", _G.Filters.MinSizeClass, true, function(v) _G.Filters.MinSizeClass = v end)
createInput("Min Weight", _G.Filters.MinWeightKg, true, function(v) _G.Filters.MinWeightKg = v end)

createLabel("--- LIVE STATS ---")
local CashLabel = createLabel("Cash: Loading...")
local CarryLabel = createLabel("Capacity: Loading...")

-- Auto-resize scrolling frame
Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 20)
UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Container.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y + 20)
end)

-- Update Stats GUI loop
task.spawn(function()
    while task.wait(1) do
        local RealStats = getRealStats()
        if RealStats then
            if RealStats:FindFirstChild("Cash") then
                CashLabel.Text = "Cash: $" .. tostring(RealStats.Cash.Value)
            end
            if RealStats:FindFirstChild("CarryWeight") then
                CarryLabel.Text = "Carry Wght Capacity: " .. tostring(RealStats.CarryWeight.Value)
            end
        end
    end
end)
