-- =========================================================================
-- Waypoint Tween Pathing + Aura & Anti-AFK GUI
-- =========================================================================

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

local waypoints = {}
local isRunning = false

-- Feature States
local antiAfkEnabled = false
local autoPromptEnabled = false
local autoTouchEnabled = false
local antiAfkConnection = nil

-- =========================================================================
-- GUI CREATION
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WaypointFarmerGUI"
ScreenGui.ResetOnSpawn = false

-- Safely mount GUI (supports both Studio and Executors)
local success, coreGui = pcall(function() return game:GetService("CoreGui") end)
ScreenGui.Parent = (success and coreGui) and coreGui or LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 260, 0, 550)
MainFrame.Position = UDim2.new(0.5, -130, 0.5, -275)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true 

local UIListLayout = Instance.new("UIListLayout", MainFrame)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local UIPadding = Instance.new("UIPadding", MainFrame)
UIPadding.PaddingTop = UDim.new(0, 10)
UIPadding.PaddingBottom = UDim.new(0, 10)

-- Helper function to create UI elements
local function createUIElement(class, properties)
    local element = Instance.new(class)
    for k, v in pairs(properties) do
        element[k] = v
    end
    element.Parent = MainFrame
    return element
end

-- --- TITLE ---
createUIElement("TextLabel", {
    Size = UDim2.new(1, -20, 0, 25),
    BackgroundTransparency = 1,
    Text = "Waypoint & Aura Hub",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 16
})

-- --- PATHING SETTINGS ---
local SpeedInput = createUIElement("TextBox", {
    Size = UDim2.new(1, -20, 0, 30),
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.Gotham,
    PlaceholderText = "Speed (Studs/Sec) [Default: 50]",
    Text = "50",
    TextSize = 13
})

local SleepInput = createUIElement("TextBox", {
    Size = UDim2.new(1, -20, 0, 30),
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.Gotham,
    PlaceholderText = "Sleep (Seconds) [Default: 1]",
    Text = "1",
    TextSize = 13
})

local AddWPBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    BackgroundColor3 = Color3.fromRGB(40, 160, 60),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    Text = "Add Waypoint Here",
    TextSize = 13
})

local ClearWPBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    BackgroundColor3 = Color3.fromRGB(180, 50, 50),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    Text = "Clear All Waypoints",
    TextSize = 13
})

local StatusLabel = createUIElement("TextLabel", {
    Size = UDim2.new(1, -20, 0, 20),
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(200, 200, 200),
    Font = Enum.Font.Gotham,
    Text = "Waypoints: 0",
    TextSize = 12
})

local TogglePathingBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 40),
    BackgroundColor3 = Color3.fromRGB(0, 120, 210),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBlack,
    Text = "START PATHING",
    TextSize = 16
})

-- --- DIVIDER ---
createUIElement("Frame", {
    Size = UDim2.new(1, -40, 0, 2),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})

-- --- EXTRA FEATURES SETTINGS ---
local AuraRadiusInput = createUIElement("TextBox", {
    Size = UDim2.new(1, -20, 0, 30),
    BackgroundColor3 = Color3.fromRGB(50, 50, 55),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.Gotham,
    PlaceholderText = "Aura Radius (Studs) [Default: 20]",
    Text = "20",
    TextSize = 13
})

local TogglePromptBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    BackgroundColor3 = Color3.fromRGB(180, 50, 50),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    Text = "Auto-Fire Prompts: OFF",
    TextSize = 13
})

local ToggleTouchBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    BackgroundColor3 = Color3.fromRGB(180, 50, 50),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    Text = "Auto-Touch Parts: OFF",
    TextSize = 13
})

local ToggleAFKBtn = createUIElement("TextButton", {
    Size = UDim2.new(1, -20, 0, 35),
    BackgroundColor3 = Color3.fromRGB(180, 50, 50),
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    Text = "Anti-AFK: OFF",
    TextSize = 13
})


-- =========================================================================
-- LOGIC & FUNCTIONS
-- =========================================================================

-- Pathing Logic
local function tweenTo(targetCFrame)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    local speed = tonumber(SpeedInput.Text) or 50
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = distance / speed
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Wait()
end

AddWPBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        table.insert(waypoints, char.HumanoidRootPart.CFrame)
        StatusLabel.Text = "Waypoints: " .. #waypoints
    end
end)

ClearWPBtn.MouseButton1Click:Connect(function()
    waypoints = {}
    StatusLabel.Text = "Waypoints: 0"
end)

TogglePathingBtn.MouseButton1Click:Connect(function()
    if #waypoints == 0 then return end 
    isRunning = not isRunning
    
    if isRunning then
        TogglePathingBtn.Text = "STOP PATHING"
        TogglePathingBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        
        task.spawn(function()
            while isRunning do
                for i, wpCFrame in ipairs(waypoints) do
                    if not isRunning then break end
                    tweenTo(wpCFrame)
                    if not isRunning then break end
                    
                    local sleepDuration = tonumber(SleepInput.Text) or 1
                    task.wait(sleepDuration)
                end
            end
            TogglePathingBtn.Text = "START PATHING"
            TogglePathingBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
        end)
    else
        TogglePathingBtn.Text = "START PATHING"
        TogglePathingBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 210)
    end
end)

-- Anti-AFK Logic
ToggleAFKBtn.MouseButton1Click:Connect(function()
    antiAfkEnabled = not antiAfkEnabled
    if antiAfkEnabled then
        ToggleAFKBtn.Text = "Anti-AFK: ON"
        ToggleAFKBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
        
        -- Hooks into the game's idle detection and fakes a mouse click
        antiAfkConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    else
        ToggleAFKBtn.Text = "Anti-AFK: OFF"
        ToggleAFKBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
    end
end)

-- Aura Features (Prompts & Touch)
TogglePromptBtn.MouseButton1Click:Connect(function()
    autoPromptEnabled = not autoPromptEnabled
    TogglePromptBtn.Text = autoPromptEnabled and "Auto-Fire Prompts: ON" or "Auto-Fire Prompts: OFF"
    TogglePromptBtn.BackgroundColor3 = autoPromptEnabled and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(180, 50, 50)
end)

ToggleTouchBtn.MouseButton1Click:Connect(function()
    autoTouchEnabled = not autoTouchEnabled
    ToggleTouchBtn.Text = autoTouchEnabled and "Auto-Touch Parts: ON" or "Auto-Touch Parts: OFF"
    ToggleTouchBtn.BackgroundColor3 = autoTouchEnabled and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(180, 50, 50)
end)

-- Aura Loop (Runs constantly in the background, executing actions if toggled ON)
task.spawn(function()
    while task.wait(0.5) do
        if not (autoPromptEnabled or autoTouchEnabled) then continue end
        
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local radius = tonumber(AuraRadiusInput.Text) or 20
        
        -- Scan the workspace for interactables
        for _, obj in ipairs(workspace:GetDescendants()) do
            
            -- Proximity Prompt Aura
            if autoPromptEnabled and obj:IsA("ProximityPrompt") then
                local p = obj.Parent
                if p and p:IsA("BasePart") and (p.Position - hrp.Position).Magnitude <= radius then
                    if fireproximityprompt then
                        fireproximityprompt(obj)
                    end
                elseif p and p:IsA("Model") and p.PrimaryPart and (p.PrimaryPart.Position - hrp.Position).Magnitude <= radius then
                    if fireproximityprompt then
                        fireproximityprompt(obj)
                    end
                end
            end
            
            -- Touch Interest / TouchTransmitter Aura
            if autoTouchEnabled and obj:IsA("TouchTransmitter") then
                local p = obj.Parent
                if p and p:IsA("BasePart") and (p.Position - hrp.Position).Magnitude <= radius then
                    if firetouchinterest then
                        -- Fire touch ON (0) and OFF (1) to simulate walking into and out of the part
                        firetouchinterest(hrp, p, 0)
                        task.wait()
                        firetouchinterest(hrp, p, 1)
                    end
                end
            end
            
        end
    end
end)
