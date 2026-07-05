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
    InstantPrompt = true, -- Instant React Prompt
    
    -- Filters
    Filters = {
        ApplyToFarm = false,
        ApplyToESP = false,
        MinValue = 0,
        MinSizeClass = 0,
        MinWeightKg = 0,
        MinTier = 0
    }
}

--// Utility Functions
local function formatNumber(n)
    n = tonumber(n)
    if not n then return "0" end
    
    if n >= 1e12 then
        return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

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
local function passesFilter(crystal, forFarm)
    if forFarm and not _G.Filters.ApplyToFarm then return true end
    if not forFarm and not _G.Filters.ApplyToESP then return true end
    
    local valueAttr = crystal:GetAttribute("Value") or 0
    local sizeAttr = crystal:GetAttribute("sizeclass") or 0
    local weightAttr = crystal:GetAttribute("weightkg") or 0
    local tierAttr = crystal:GetAttribute("tier") or 0

    if tonumber(valueAttr) < _G.Filters.MinValue then return false end
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
                if passesFilter(crystal, true) then
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

-- Instant Prompt Loop
task.spawn(function()
    while task.wait(1) do
        if _G.InstantPrompt then
            local function modifyPrompts(folder)
                if not folder then return end
                for _, desc in ipairs(folder:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.HoldDuration > 0 then
                        desc.HoldDuration = 0
                    end
                end
            end
            modifyPrompts(Workspace:FindFirstChild("Things"))
            modifyPrompts(getDroppedCrystalsFolder())
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
                            if prompt and passesFilter(part, true) then
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
                    if passesFilter(part, false) then
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
                            
                            local val = part:GetAttribute("Value") or 0
                            local tier = part:GetAttribute("tier") or "?"
                            textLabel.Text = string.format("Value: %s\n[Tier %s]", formatNumber(val), tostring(tier))
                            
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

--// Native GUI Construction (Expert Remaster)
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
MainFrame.Size = UDim2.new(0, 500, 0, 360)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

local SidebarFix = Instance.new("Frame")
SidebarFix.Size = UDim2.new(0, 10, 1, 0)
SidebarFix.Position = UDim2.new(1, -10, 0, 0)
SidebarFix.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
SidebarFix.BorderSizePixel = 0
SidebarFix.Parent = Sidebar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 60)
Title.BackgroundTransparency = 1
Title.Text = "Crystal Hub"
Title.TextColor3 = Color3.fromRGB(243, 244, 246)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Sidebar

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 1, -70)
TabContainer.Position = UDim2.new(0, 0, 0, 70)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Sidebar

local TabListLayout = Instance.new("UIListLayout")
TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabListLayout.Padding = UDim.new(0, 6)
TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabListLayout.Parent = TabContainer

-- Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, 0)
ContentArea.Position = UDim2.new(0, 140, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local CurrentTab = nil

-- UI Library Functions
local function CreateTab(name)
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(0.85, 0, 0, 34)
    TabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    TabBtn.BackgroundTransparency = 1
    TabBtn.Text = name
    TabBtn.TextColor3 = Color3.fromRGB(156, 163, 175)
    TabBtn.Font = Enum.Font.GothamSemibold
    TabBtn.TextSize = 13
    TabBtn.Parent = TabContainer
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

    local TabContent = Instance.new("ScrollingFrame")
    TabContent.Size = UDim2.new(1, -30, 1, -30)
    TabContent.Position = UDim2.new(0, 15, 0, 15)
    TabContent.BackgroundTransparency = 1
    TabContent.ScrollBarThickness = 3
    TabContent.ScrollBarImageColor3 = Color3.fromRGB(99, 102, 241)
    TabContent.Visible = false
    TabContent.Parent = ContentArea

    local UIList = Instance.new("UIListLayout")
    UIList.SortOrder = Enum.SortOrder.LayoutOrder
    UIList.Padding = UDim.new(0, 12)
    UIList.Parent = TabContent

    UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabContent.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 10)
    end)

    TabBtn.MouseButton1Click:Connect(function()
        if CurrentTab then
            CurrentTab.Btn.BackgroundTransparency = 1
            CurrentTab.Btn.TextColor3 = Color3.fromRGB(156, 163, 175)
            CurrentTab.Content.Visible = false
        end
        TabBtn.BackgroundTransparency = 0
        TabBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabContent.Visible = true
        CurrentTab = {Btn = TabBtn, Content = TabContent}
    end)

    table.insert(Tabs, {Btn = TabBtn, Content = TabContent})
    if #Tabs == 1 then
        TabBtn.BackgroundTransparency = 0
        TabBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
        TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabContent.Visible = true
        CurrentTab = Tabs[1]
    end

    return TabContent
end

local function CreateToggle(parent, name, defaultState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(243, 244, 246)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 44, 0, 24)
    ToggleBtn.Position = UDim2.new(1, -55, 0.5, -12)
    ToggleBtn.BackgroundColor3 = defaultState and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60, 60, 65)
    ToggleBtn.Text = ""
    ToggleBtn.Parent = frame
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 20, 0, 20)
    Circle.Position = defaultState and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Circle.Parent = ToggleBtn
    Instance.new("UICorner", Circle).CornerRadius = UDim.new(1, 0)

    local state = defaultState
    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        
        local targetColor = state and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60, 60, 65)
        local targetPos = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
        
        TweenService:Create(ToggleBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(Circle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
    end)
end

local function CreateInput(parent, name, defaultValue, isNumber, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Color3.fromRGB(243, 244, 246)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.35, -15, 0, 28)
    box.Position = UDim2.new(0.65, 0, 0.5, -14)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Text = tostring(defaultValue)
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.Parent = frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    box.FocusLost:Connect(function()
        local val = box.Text
        if isNumber then
            val = tonumber(val) or defaultValue
            box.Text = tostring(val)
        end
        callback(val)
    end)
end

local function CreateLabel(parent, text)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(99, 102, 241)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    return label
end

-- Populate GUI Elements
local TabMain = CreateTab("Main Controls")
CreateToggle(TabMain, "Auto Farm Crystals", _G.AutoFarm, function(v) _G.AutoFarm = v end)
CreateToggle(TabMain, "Auto Sell (When Bag Full)", _G.AutoSell, function(v) _G.AutoSell = v end)
CreateToggle(TabMain, "Instant React Prompt", _G.InstantPrompt, function(v) _G.InstantPrompt = v end)
CreateInput(TabMain, "Tween Speed (Studs/s)", _G.TweenSpeed, true, function(v) _G.TweenSpeed = v end)

local TabAura = CreateTab("Aura Grab")
CreateToggle(TabAura, "Enable Aura Grab", _G.GrabRadiusEnabled, function(v) _G.GrabRadiusEnabled = v end)
CreateInput(TabAura, "Grab Radius", _G.GrabRadius, true, function(v) _G.GrabRadius = v end)

local TabFilter = CreateTab("Filters & ESP")
CreateToggle(TabFilter, "Enable Visual ESP", _G.ESP, function(v) _G.ESP = v end)
CreateToggle(TabFilter, "Apply Filters to Farm", _G.Filters.ApplyToFarm, function(v) _G.Filters.ApplyToFarm = v end)
CreateToggle(TabFilter, "Apply Filters to ESP", _G.Filters.ApplyToESP, function(v) _G.Filters.ApplyToESP = v end)
CreateInput(TabFilter, "Min Value", _G.Filters.MinValue, true, function(v) _G.Filters.MinValue = v end)
CreateInput(TabFilter, "Min Tier", _G.Filters.MinTier, true, function(v) _G.Filters.MinTier = v end)
CreateInput(TabFilter, "Min Size", _G.Filters.MinSizeClass, true, function(v) _G.Filters.MinSizeClass = v end)
CreateInput(TabFilter, "Min Weight", _G.Filters.MinWeightKg, true, function(v) _G.Filters.MinWeightKg = v end)

local TabStats = CreateTab("Live Stats")
local CashLabel = CreateLabel(TabStats, "Cash: Loading...")
local CarryLabel = CreateLabel(TabStats, "Capacity: Loading...")

-- Update Stats GUI loop
task.spawn(function()
    while task.wait(1) do
        local RealStats = getRealStats()
        if RealStats then
            if RealStats:FindFirstChild("Cash") then
                CashLabel.Text = "Cash: $" .. formatNumber(RealStats.Cash.Value)
            end
            if RealStats:FindFirstChild("CarryWeight") then
                CarryLabel.Text = "Carry Wght Capacity: " .. formatNumber(RealStats.CarryWeight.Value)
            end
        end
    end
end)
