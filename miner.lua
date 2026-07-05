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
local UserInputService = game:GetService("UserInputService")

--// Variables
local LocalPlayer = Players.LocalPlayer
local Connections = {} -- Stores events to disconnect on termination

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
    HubRunning = true,
    AutoFarm = false,
    AutoSell = false,
    ESP = false,
    GrabRadiusEnabled = false,
    GrabRadius = 20,
    TweenSpeed = 30, -- Studs per second
    MaxWeight = 100, -- Fallback value
    InstantPrompt = true, -- Instant React Prompt
    
    InfJump = true, -- On by default
    SpeedEnabled = false,
    PlayerSpeed = 50,
    
    -- ESP Visuals Configuration
    ESPConfig = {
        ShowValue = true,
        ShowTier = true,
        TextSize = 14,
        ColorR = 0,
        ColorG = 255,
        ColorB = 255
    },
    
    -- Filters
    Filters = {
        ApplyToFarm = false,
        ApplyToESP = false,
        ApplyToAura = false,
        MinValue = 0,
        MinWeightKg = 0,
        Tiers = {
            Mythic = true,
            Legendary = true,
            Epic = true,
            Rare = true,
            Uncommon = true,
            Common = true
        }
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
local function passesFilter(crystal, context)
    if context == "Farm" and not _G.Filters.ApplyToFarm then return true end
    if context == "ESP" and not _G.Filters.ApplyToESP then return true end
    if context == "Aura" and not _G.Filters.ApplyToAura then return true end
    
    local valueAttr = crystal:GetAttribute("Value") or 0
    local weightAttr = crystal:GetAttribute("weightkg") or 0
    local tierAttr = crystal:GetAttribute("TierName") or "Unknown"

    if tonumber(valueAttr) < _G.Filters.MinValue then return false end
    if tonumber(weightAttr) < _G.Filters.MinWeightKg then return false end
    
    -- Check if the specific TierName is allowed in the filter list
    if _G.Filters.Tiers[tierAttr] == false then return false end

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
    
    local maxWeight = RealStats:FindFirstChild("CarryWeight") and RealStats.CarryWeight.Value or _G.MaxWeight
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
    
    local prompt = SellProx:FindFirstChildWhichIsA("ProximityPrompt", true) 
    if prompt then
        local targetCFrame = SellProx:IsA("Model") and SellProx:GetPivot() or SellProx.CFrame
        tweenTo(targetCFrame * CFrame.new(0, 0, 3)) 
        
        task.wait(0.2)
        firePrompt(prompt)
        
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
                if passesFilter(crystal, "Farm") then
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

--// Events & Connections
table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if _G.InfJump and _G.HubRunning then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end))

table.insert(Connections, RunService.Stepped:Connect(function()
    if not _G.HubRunning then return end
    
    local char = LocalPlayer.Character
    if char then
        -- Noclip for AutoFarm
        if _G.AutoFarm then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
        -- Player Speed Modifier
        if _G.SpeedEnabled then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum.WalkSpeed = _G.PlayerSpeed
            end
        end
    end
end))

--// Main Loops
-- Instant Prompt Loop
task.spawn(function()
    while _G.HubRunning and task.wait(1) do
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
    while _G.HubRunning and task.wait(0.1) do
        if _G.AutoFarm then
            if _G.AutoSell and isBagFull() then
                performSell()
            else
                local target = getNearestCrystal()
                if target and target.Parent then
                    tweenTo(target.CFrame)
                    
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
    while _G.HubRunning and task.wait(0.1) do
        if _G.GrabRadiusEnabled then
            local hrp = getHRP()
            if hrp then
                local function grabFrom(folder)
                    if not folder then return end
                    for _, crystal in ipairs(folder:GetChildren()) do
                        local part = crystal:IsA("Model") and crystal.PrimaryPart or crystal
                        if part and part:IsA("BasePart") then
                            local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and passesFilter(part, "Aura") then
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
    while _G.HubRunning and task.wait(0.5) do
        if not _G.ESP then
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
                    if passesFilter(part, "ESP") then
                        if not ESPObjects[part] then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Name = "CrystalESP"
                            billboard.AlwaysOnTop = true
                            billboard.Size = UDim2.new(0, 150, 0, 50)
                            billboard.StudsOffset = Vector3.new(0, 2, 0)
                            billboard.Adornee = part
                            
                            local textLabel = Instance.new("TextLabel", billboard)
                            textLabel.Size = UDim2.new(1, 0, 1, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.TextScaled = false
                            textLabel.TextStrokeTransparency = 0
                            
                            local safeParent = (gethui and gethui()) or game:GetService("CoreGui")
                            if not pcall(function() local _ = safeParent.Name end) then safeParent = LocalPlayer:WaitForChild("PlayerGui") end
                            billboard.Parent = safeParent
                            
                            ESPObjects[part] = billboard
                        end
                        
                        -- Update visuals based on config
                        if ESPObjects[part] then
                            local txtLabel = ESPObjects[part]:FindFirstChildOfClass("TextLabel")
                            if txtLabel then
                                txtLabel.TextColor3 = Color3.fromRGB(_G.ESPConfig.ColorR, _G.ESPConfig.ColorG, _G.ESPConfig.ColorB)
                                txtLabel.TextSize = _G.ESPConfig.TextSize
                                
                                local val = part:GetAttribute("Value") or 0
                                local tier = part:GetAttribute("TierName") or "?"
                                
                                local content = ""
                                if _G.ESPConfig.ShowValue then content = content .. string.format("Value: %s\n", formatNumber(val)) end
                                if _G.ESPConfig.ShowTier then content = content .. string.format("[%s]", tostring(tier)) end
                                txtLabel.Text = content
                            end
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
MainFrame.Size = UDim2.new(0, 500, 0, 380)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Keybind Toggle
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        MainFrame.Visible = not MainFrame.Visible
    end
end))

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -40, 0, 10)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 18
MinimizeBtn.ZIndex = 10
MinimizeBtn.Parent = MainFrame
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    -- Can be brought back with K
end)

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
TabContainer.Size = UDim2.new(1, 0, 1, -110)
TabContainer.Position = UDim2.new(0, 0, 0, 60)
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
    TabContent.Size = UDim2.new(1, -30, 1, -40)
    TabContent.Position = UDim2.new(0, 15, 0, 20)
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

local function CreateMultiDropdown(parent, name, optionsDict, orderList)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 42)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    frame.ClipsDescendants = true
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local topBtn = Instance.new("TextButton")
    topBtn.Size = UDim2.new(1, 0, 0, 42)
    topBtn.BackgroundTransparency = 1
    topBtn.Text = "  " .. name
    topBtn.TextColor3 = Color3.fromRGB(243, 244, 246)
    topBtn.Font = Enum.Font.GothamBold
    topBtn.TextSize = 13
    topBtn.TextXAlignment = Enum.TextXAlignment.Left
    topBtn.Parent = frame

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 30, 0, 42)
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▼"
    arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 12
    arrow.Parent = frame

    local itemsContainer = Instance.new("Frame")
    itemsContainer.Size = UDim2.new(1, 0, 0, 0)
    itemsContainer.Position = UDim2.new(0, 0, 0, 42)
    itemsContainer.BackgroundTransparency = 1
    itemsContainer.Parent = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = itemsContainer

    local isOpen = false
    topBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        arrow.Text = isOpen and "▲" or "▼"
        local targetHeight = isOpen and (42 + listLayout.AbsoluteContentSize.Y) or 42
        TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
    end)

    for _, optName in ipairs(orderList) do
        local optFrame = Instance.new("Frame")
        optFrame.Size = UDim2.new(1, 0, 0, 34)
        optFrame.BackgroundTransparency = 1
        optFrame.Parent = itemsContainer

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -50, 1, 0)
        lbl.Position = UDim2.new(0, 15, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = optName
        lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = optFrame

        local box = Instance.new("TextButton")
        box.Size = UDim2.new(0, 20, 0, 20)
        box.Position = UDim2.new(1, -35, 0.5, -10)
        box.BackgroundColor3 = optionsDict[optName] and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60, 60, 65)
        box.Text = ""
        box.Parent = optFrame
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

        box.MouseButton1Click:Connect(function()
            optionsDict[optName] = not optionsDict[optName]
            local targetColor = optionsDict[optName] and Color3.fromRGB(99, 102, 241) or Color3.fromRGB(60, 60, 65)
            TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        end)
    end

    -- Automatically resize when items are populated
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if isOpen then
            frame.Size = UDim2.new(1, 0, 0, 42 + listLayout.AbsoluteContentSize.Y)
        end
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

local TabLocal = CreateTab("Local Player")
CreateToggle(TabLocal, "Infinite Jump", _G.InfJump, function(v) _G.InfJump = v end)
CreateToggle(TabLocal, "Enable WalkSpeed", _G.SpeedEnabled, function(v) _G.SpeedEnabled = v end)
CreateInput(TabLocal, "Player WalkSpeed", _G.PlayerSpeed, true, function(v) _G.PlayerSpeed = v end)

local TabAura = CreateTab("Aura Grab")
CreateToggle(TabAura, "Enable Aura Grab", _G.GrabRadiusEnabled, function(v) _G.GrabRadiusEnabled = v end)
CreateInput(TabAura, "Grab Radius", _G.GrabRadius, true, function(v) _G.GrabRadius = v end)

local TabFilter = CreateTab("Filters & ESP")
CreateToggle(TabFilter, "Enable Visual ESP", _G.ESP, function(v) _G.ESP = v end)
CreateToggle(TabFilter, "Apply Filters to Farm", _G.Filters.ApplyToFarm, function(v) _G.Filters.ApplyToFarm = v end)
CreateToggle(TabFilter, "Apply Filters to ESP", _G.Filters.ApplyToESP, function(v) _G.Filters.ApplyToESP = v end)
CreateToggle(TabFilter, "Apply Filters to Aura Grab", _G.Filters.ApplyToAura, function(v) _G.Filters.ApplyToAura = v end)
CreateInput(TabFilter, "Min Value", _G.Filters.MinValue, true, function(v) _G.Filters.MinValue = v end)
CreateInput(TabFilter, "Min Weight", _G.Filters.MinWeightKg, true, function(v) _G.Filters.MinWeightKg = v end)

-- Added Dropdown list for Tier filtering
CreateMultiDropdown(TabFilter, "Filter by Tiers", _G.Filters.Tiers, {
    "Mythic",
    "Legendary",
    "Epic",
    "Rare",
    "Uncommon",
    "Common"
})

local TabVisuals = CreateTab("ESP Visuals")
CreateToggle(TabVisuals, "Show Crystal Value", _G.ESPConfig.ShowValue, function(v) _G.ESPConfig.ShowValue = v end)
CreateToggle(TabVisuals, "Show Crystal Tier", _G.ESPConfig.ShowTier, function(v) _G.ESPConfig.ShowTier = v end)
CreateInput(TabVisuals, "Text Size", _G.ESPConfig.TextSize, true, function(v) _G.ESPConfig.TextSize = v end)
CreateInput(TabVisuals, "Color: Red (0-255)", _G.ESPConfig.ColorR, true, function(v) _G.ESPConfig.ColorR = math.clamp(v, 0, 255) end)
CreateInput(TabVisuals, "Color: Green (0-255)", _G.ESPConfig.ColorG, true, function(v) _G.ESPConfig.ColorG = math.clamp(v, 0, 255) end)
CreateInput(TabVisuals, "Color: Blue (0-255)", _G.ESPConfig.ColorB, true, function(v) _G.ESPConfig.ColorB = math.clamp(v, 0, 255) end)

local TabStats = CreateTab("Live Stats")
local CashLabel = CreateLabel(TabStats, "Cash: Loading...")
local CarryLabel = CreateLabel(TabStats, "Capacity: Loading...")

-- Termination Button in Sidebar
local TerminateBtn = Instance.new("TextButton")
TerminateBtn.Size = UDim2.new(0.85, 0, 0, 34)
TerminateBtn.Position = UDim2.new(0.075, 0, 1, -45)
TerminateBtn.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
TerminateBtn.Text = "Terminate Hub"
TerminateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TerminateBtn.Font = Enum.Font.GothamBold
TerminateBtn.TextSize = 13
TerminateBtn.Parent = Sidebar
Instance.new("UICorner", TerminateBtn).CornerRadius = UDim.new(0, 6)

TerminateBtn.MouseButton1Click:Connect(function()
    _G.HubRunning = false
    
    for _, conn in ipairs(Connections) do
        conn:Disconnect()
    end
    table.clear(Connections)
    
    for _, gui in pairs(ESPObjects) do
        if gui then gui:Destroy() end
    end
    table.clear(ESPObjects)
    
    if safeParent:FindFirstChild("CrystalNativeHub") then
        safeParent.CrystalNativeHub:Destroy()
    end
end)

-- Update Stats GUI loop
task.spawn(function()
    while _G.HubRunning and task.wait(1) do
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
