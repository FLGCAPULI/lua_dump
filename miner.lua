--[[
    Crystal Auto-Farm & ESP Hub (Remastered)
    Features: Filterable ESP, Tween Auto Farm, Auto Sell, Grab Radius
]]

--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

--// Variables
local LocalPlayer = Players.LocalPlayer
local Connections = {} -- Stores events to disconnect on termination
local ActiveTween = nil -- Stores the current active tween

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

--// Configuration / State (Replaced _G with a safer local state)
local State = {
    HubRunning = true,
    AutoFarm = false,
    AutoSell = false,
    ESP = false,
    GrabRadiusEnabled = false,
    PreventOverweight = true,
    GrabRadius = 20,
    TweenSpeed = 30,
    MaxWeight = 100,
    InstantPrompt = true,
    
    InfJump = true,
    SpeedEnabled = false,
    PlayerSpeed = 50,
    
    ESPConfig = {
        ShowValue = true,
        ShowTier = true,
        ShowDistance = true,
        TextSize = 14,
        ColorR = 0,
        ColorG = 255,
        ColorB = 255
    },
    
    Filters = {
        Farm = {
            Apply = false,
            MinValue = 0,
            MinWeightKg = 0,
            Tiers = { Mythic = true, Legendary = true, Epic = true, Rare = true, Uncommon = true, Common = true }
        },
        ESP = {
            Apply = false,
            MinValue = 0,
            MinWeightKg = 0,
            Tiers = { Mythic = true, Legendary = true, Epic = true, Rare = true, Uncommon = true, Common = true }
        },
        Aura = {
            Apply = false,
            MinValue = 0,
            MinWeightKg = 0,
            Tiers = { Mythic = true, Legendary = true, Epic = true, Rare = true, Uncommon = true, Common = true }
        }
    }
}

--// Utility Functions
local function formatNumber(n)
    n = tonumber(n)
    if not n then return "0" end
    
    if n >= 1e12 then return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
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
            fireproximityprompt(prompt)
        else
            prompt.HoldDuration = 0
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end
    end
end

local function passesFilter(crystal, context)
    local filterConfig = State.Filters[context]
    if not filterConfig then return true end
    if not filterConfig.Apply then return true end
    
    local valueAttr = crystal:GetAttribute("Value") or 0
    local weightAttr = crystal:GetAttribute("WeightKg") or 0
    local tierAttr = crystal:GetAttribute("TierName") or "Unknown"

    if tonumber(valueAttr) < filterConfig.MinValue then return false end
    if tonumber(weightAttr) < filterConfig.MinWeightKg then return false end
    if filterConfig.Tiers[tierAttr] == false then return false end

    return true
end

-- Safely tween and allow cancellation if object is destroyed
local function tweenTo(targetCFrame, targetInstance)
    local hrp = getHRP()
    if not hrp then return end
    
    if ActiveTween then ActiveTween:Cancel() end
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local timeToTween = distance / State.TweenSpeed
    
    local tweenInfo = TweenInfo.new(timeToTween, Enum.EasingStyle.Linear)
    ActiveTween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    ActiveTween:Play()
    
    -- Custom wait loop so we can abort if the crystal disappears
    while ActiveTween and ActiveTween.PlaybackState == Enum.PlaybackState.Playing do
        if not State.AutoFarm or (targetInstance and not targetInstance.Parent) then
            ActiveTween:Cancel()
            break
        end
        task.wait(0.05)
    end
end

local function isBagFull()
    local RealStats = getRealStats()
    if not RealStats then return false end
    
    local maxWeight = RealStats:FindFirstChild("CarryWeight") and RealStats.CarryWeight.Value or State.MaxWeight
    local currentWeight = RealStats:FindFirstChild("CurrentWeight") and RealStats.CurrentWeight.Value or 0 
    
    return currentWeight >= maxWeight and maxWeight > 0
end

local function canCarry(weightToAdd)
    local RealStats = getRealStats()
    if not RealStats then return true end
    
    local maxWeight = RealStats:FindFirstChild("CarryWeight") and RealStats.CarryWeight.Value or State.MaxWeight
    local currentWeight = RealStats:FindFirstChild("CurrentWeight") and RealStats.CurrentWeight.Value or 0 
    
    return (currentWeight + weightToAdd) <= maxWeight
end

local function performSell()
    local SellProx = getSellProx()
    if not SellProx then return end
    
    local prompt = SellProx:FindFirstChildWhichIsA("ProximityPrompt", true) 
    if prompt then
        local targetCFrame = SellProx:IsA("Model") and SellProx:GetPivot() or SellProx.CFrame
        tweenTo(targetCFrame * CFrame.new(0, 0, 3), SellProx) 
        
        task.wait(0.2)
        firePrompt(prompt)
        
        task.wait(0.5)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
        task.wait(1)
    end
end

local function getNearestCrystal()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local nearestDist = math.huge
    local nearestCrystal = nil
    
    local function checkFolder(folder)
        if not folder then return end
        for _, crystal in ipairs(folder:GetChildren()) do
            local part = crystal:IsA("Model") and crystal.PrimaryPart or crystal
            
            if part:IsA("BasePart") and part:FindFirstChildOfClass("ProximityPrompt") then
                if passesFilter(part, "Farm") then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < nearestDist then
                        nearestDist = dist
                        nearestCrystal = part
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
    if State.InfJump and State.HubRunning then
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
    if not State.HubRunning then return end
    
    local char = LocalPlayer.Character
    if char then
        -- Optimized Noclip (Only checks top-level children, not deep descendants)
        if State.AutoFarm then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
        if State.SpeedEnabled then
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            if hum then
                hum.WalkSpeed = State.PlayerSpeed
            end
        end
    end
end))

--// Main Loops
task.spawn(function()
    while State.HubRunning and task.wait(1) do
        if State.InstantPrompt then
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

task.spawn(function()
    while State.HubRunning and task.wait(0.1) do
        if State.AutoFarm then
            if State.AutoSell and isBagFull() then
                performSell()
            else
                local target = getNearestCrystal()
                if target and target.Parent then
                    tweenTo(target.CFrame, target)
                    
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

task.spawn(function()
    while State.HubRunning and task.wait(0.1) do
        if State.GrabRadiusEnabled then
            local hrp = getHRP()
            if hrp then
                local function grabFrom(folder)
                    if not folder then return end
                    for _, crystal in ipairs(folder:GetChildren()) do
                        local part = crystal:IsA("Model") and crystal.PrimaryPart or crystal
                        if part and part:IsA("BasePart") then
                            local prompt = part:FindFirstChildOfClass("ProximityPrompt")
                            if prompt and passesFilter(part, "Aura") then
                                local weight = tonumber(part:GetAttribute("WeightKg")) or 0
                                
                                if not State.PreventOverweight or canCarry(weight) then
                                    local dist = (hrp.Position - part.Position).Magnitude
                                    if dist <= State.GrabRadius then
                                        firePrompt(prompt)
                                    end
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

local ESPObjects = {}
task.spawn(function()
    while State.HubRunning and task.wait(0.5) do
        if not State.ESP then
            for part, gui in pairs(ESPObjects) do
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
                            
                            local safeParent = (gethui and gethui()) or CoreGui
                            if not pcall(function() local _ = safeParent.Name end) then safeParent = LocalPlayer:WaitForChild("PlayerGui") end
                            billboard.Parent = safeParent
                            
                            ESPObjects[part] = billboard
                            
                            -- Cleanup when crystal is destroyed
                            local conn; conn = part.AncestryChanged:Connect(function(_, parent)
                                if not parent then
                                    if ESPObjects[part] then ESPObjects[part]:Destroy() end
                                    ESPObjects[part] = nil
                                    conn:Disconnect()
                                end
                            end)
                        end
                        
                        if ESPObjects[part] then
                            local txtLabel = ESPObjects[part]:FindFirstChildOfClass("TextLabel")
                            if txtLabel then
                                txtLabel.TextColor3 = Color3.fromRGB(State.ESPConfig.ColorR, State.ESPConfig.ColorG, State.ESPConfig.ColorB)
                                txtLabel.TextSize = State.ESPConfig.TextSize
                                
                                local val = part:GetAttribute("Value") or 0
                                local tier = part:GetAttribute("TierName") or "?"
                                
                                local lines = {}
                                if State.ESPConfig.ShowTier then table.insert(lines, string.format("[%s]", tostring(tier))) end
                                if State.ESPConfig.ShowValue then table.insert(lines, string.format("Value: %s", formatNumber(val))) end
                                if State.ESPConfig.ShowDistance then
                                    local hrp = getHRP()
                                    if hrp then
                                        local dist = math.floor((hrp.Position - part.Position).Magnitude)
                                        table.insert(lines, string.format("%dm", dist))
                                    end
                                end
                                txtLabel.Text = table.concat(lines, "\n")
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
    end
end)

--// Native GUI Construction
local safeParent = (gethui and gethui()) or CoreGui
if not pcall(function() local _ = safeParent.Name end) then safeParent = LocalPlayer:WaitForChild("PlayerGui") end

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
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

-- Modern Custom Dragging (Replaces Deprecated Draggable = true)
local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.K then
        MainFrame.Visible = not MainFrame.Visible
    end
end))

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
end)

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

local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -140, 1, 0)
ContentArea.Position = UDim2.new(0, 140, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Tabs = {}
local CurrentTab = nil

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

-- Populate GUI
local TabMain = CreateTab("Main Controls")
CreateToggle(TabMain, "Auto Farm Crystals", State.AutoFarm, function(v) State.AutoFarm = v end)
CreateToggle(TabMain, "Auto Sell (When Bag Full)", State.AutoSell, function(v) State.AutoSell = v end)
CreateToggle(TabMain, "Instant React Prompt", State.InstantPrompt, function(v) State.InstantPrompt = v end)
CreateInput(TabMain, "Tween Speed (Studs/s)", State.TweenSpeed, true, function(v) State.TweenSpeed = v end)

local TabLocal = CreateTab("Local Player")
CreateToggle(TabLocal, "Infinite Jump", State.InfJump, function(v) State.InfJump = v end)
CreateToggle(TabLocal, "Enable WalkSpeed", State.SpeedEnabled, function(v) State.SpeedEnabled = v end)
CreateInput(TabLocal, "Player WalkSpeed", State.PlayerSpeed, true, function(v) State.PlayerSpeed = v end)

local TabFarmFilter = CreateTab("Farm Filters")
CreateToggle(TabFarmFilter, "Apply Filters to Farm", State.Filters.Farm.Apply, function(v) State.Filters.Farm.Apply = v end)
CreateInput(TabFarmFilter, "Min Value", State.Filters.Farm.MinValue, true, function(v) State.Filters.Farm.MinValue = v end)
CreateInput(TabFarmFilter, "Min Weight", State.Filters.Farm.MinWeightKg, true, function(v) State.Filters.Farm.MinWeightKg = v end)
CreateMultiDropdown(TabFarmFilter, "Filter by Tiers", State.Filters.Farm.Tiers, { "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" })

local TabAura = CreateTab("Aura Settings")
CreateToggle(TabAura, "Enable Aura Grab", State.GrabRadiusEnabled, function(v) State.GrabRadiusEnabled = v end)
CreateToggle(TabAura, "Prevent Overweight Grabs", State.PreventOverweight, function(v) State.PreventOverweight = v end)
CreateInput(TabAura, "Grab Radius", State.GrabRadius, true, function(v) State.GrabRadius = v end)
CreateLabel(TabAura, "--- Aura Filters ---")
CreateToggle(TabAura, "Apply Filters to Aura", State.Filters.Aura.Apply, function(v) State.Filters.Aura.Apply = v end)
CreateInput(TabAura, "Min Value", State.Filters.Aura.MinValue, true, function(v) State.Filters.Aura.MinValue = v end)
CreateInput(TabAura, "Min Weight", State.Filters.Aura.MinWeightKg, true, function(v) State.Filters.Aura.MinWeightKg = v end)
CreateMultiDropdown(TabAura, "Filter by Tiers", State.Filters.Aura.Tiers, { "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" })

local TabESP = CreateTab("ESP Settings")
CreateToggle(TabESP, "Enable Visual ESP", State.ESP, function(v) State.ESP = v end)
CreateLabel(TabESP, "--- ESP Filters ---")
CreateToggle(TabESP, "Apply Filters to ESP", State.Filters.ESP.Apply, function(v) State.Filters.ESP.Apply = v end)
CreateInput(TabESP, "Min Value", State.Filters.ESP.MinValue, true, function(v) State.Filters.ESP.MinValue = v end)
CreateInput(TabESP, "Min Weight", State.Filters.ESP.MinWeightKg, true, function(v) State.Filters.ESP.MinWeightKg = v end)
CreateMultiDropdown(TabESP, "Filter by Tiers", State.Filters.ESP.Tiers, { "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" })
CreateLabel(TabESP, "--- ESP Visuals ---")
CreateToggle(TabESP, "Show Crystal Value", State.ESPConfig.ShowValue, function(v) State.ESPConfig.ShowValue = v end)
CreateToggle(TabESP, "Show Crystal Tier", State.ESPConfig.ShowTier, function(v) State.ESPConfig.ShowTier = v end)
CreateToggle(TabESP, "Show Distance", State.ESPConfig.ShowDistance, function(v) State.ESPConfig.ShowDistance = v end)
CreateInput(TabESP, "Text Size", State.ESPConfig.TextSize, true, function(v) State.ESPConfig.TextSize = v end)
CreateInput(TabESP, "Color: Red (0-255)", State.ESPConfig.ColorR, true, function(v) State.ESPConfig.ColorR = math.clamp(v, 0, 255) end)
CreateInput(TabESP, "Color: Green (0-255)", State.ESPConfig.ColorG, true, function(v) State.ESPConfig.ColorG = math.clamp(v, 0, 255) end)
CreateInput(TabESP, "Color: Blue (0-255)", State.ESPConfig.ColorB, true, function(v) State.ESPConfig.ColorB = math.clamp(v, 0, 255) end)

local TabStats = CreateTab("Live Stats")
local CashLabel = CreateLabel(TabStats, "Cash: Loading...")
local CarryLabel = CreateLabel(TabStats, "Capacity: Loading...")

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
    State.HubRunning = false
    if ActiveTween then ActiveTween:Cancel() end
    
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

task.spawn(function()
    while State.HubRunning and task.wait(1) do
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
