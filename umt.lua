local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

-- Wait securely for the player to exist
local player = Players.LocalPlayer
while not player do
    task.wait(0.1)
    player = Players.LocalPlayer
end

-- Helper to dynamically get HRP
local function getHRP()
    local char = player.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local wp1 = nil
local wp2 = nil
local isRunning = false
local loopActive = false
local isPaused = false
local forceUnloadTrigger = false

-- ANTI-AFK
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- CONFIGURATION
local VEHICLE_CAPACITY = 120 

-- ==========================================
-- 1. GUI Setup
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmGUI"
screenGui.ResetOnSpawn = false

local success = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not success then screenGui.Parent = player:WaitForChild("PlayerGui") end

local Theme = {
    BG = Color3.fromRGB(30, 30, 30),
    TabBG = Color3.fromRGB(20, 20, 20),
    Button = Color3.fromRGB(45, 45, 45),
    Text = Color3.fromRGB(220, 220, 220),
    Active = Color3.fromRGB(80, 80, 80)
}

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 220, 0, 300)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Theme.BG
frame.ClipsDescendants = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local topbar = Instance.new("Frame", frame)
topbar.Size = UDim2.new(1, 0, 0, 30)
topbar.BackgroundColor3 = Theme.TabBG
topbar.BorderSizePixel = 0

local title = Instance.new("TextLabel", topbar)
title.Size = UDim2.new(0.8, 0, 1, 0)
title.Position = UDim2.new(0.05, 0, 0, 0)
title.Text = "Auto Farm Script"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Theme.Text
title.Font = Enum.Font.Code
title.BackgroundTransparency = 1

local btnMinimize = Instance.new("TextButton", topbar)
btnMinimize.Size = UDim2.new(0.2, 0, 1, 0)
btnMinimize.Position = UDim2.new(0.8, 0, 0, 0)
btnMinimize.Text = "-"
btnMinimize.BackgroundColor3 = Theme.TabBG
btnMinimize.TextColor3 = Theme.Text
btnMinimize.Font = Enum.Font.Code
btnMinimize.BorderSizePixel = 0

local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, 0, 0, 25)
tabBar.Position = UDim2.new(0, 0, 0, 30)
tabBar.BackgroundColor3 = Theme.TabBG
tabBar.BorderSizePixel = 0

local function createTabBtn(text, pos)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(0.333, 0, 1, 0)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Theme.TabBG
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.Code
    btn.BorderSizePixel = 0
    return btn
end

local btnTabMain = createTabBtn("Main", UDim2.new(0, 0, 0, 0))
local btnTabMods = createTabBtn("Mods", UDim2.new(0.333, 0, 0, 0))
local btnTabMisc = createTabBtn("Misc", UDim2.new(0.666, 0, 0, 0))
btnTabMain.BackgroundColor3 = Theme.Active

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, 0, 1, -55)
contentFrame.Position = UDim2.new(0, 0, 0, 55)
contentFrame.BackgroundTransparency = 1

local tabMain = Instance.new("Frame", contentFrame)
tabMain.Size = UDim2.new(1, 0, 1, 0)
tabMain.BackgroundTransparency = 1

local tabMods = Instance.new("Frame", contentFrame)
tabMods.Size = UDim2.new(1, 0, 1, 0)
tabMods.BackgroundTransparency = 1
tabMods.Visible = false

local tabMisc = Instance.new("Frame", contentFrame)
tabMisc.Size = UDim2.new(1, 0, 1, 0)
tabMisc.BackgroundTransparency = 1
tabMisc.Visible = false

local function createUIElement(className, parent, pos, text)
    local el = Instance.new(className, parent)
    el.Size = UDim2.new(0.9, 0, 0, 28)
    el.Position = pos
    el.Text = text
    el.BackgroundColor3 = Theme.Button
    el.TextColor3 = Theme.Text
    el.Font = Enum.Font.Code
    el.TextSize = 13
    Instance.new("UICorner", el).CornerRadius = UDim.new(0, 6)
    return el
end

local lblStatus = Instance.new("TextLabel", tabMain)
lblStatus.Size = UDim2.new(0.9, 0, 0, 20)
lblStatus.Position = UDim2.new(0.05, 0, 0, 10)
lblStatus.Text = "Status: Idle"
lblStatus.TextColor3 = Theme.Text
lblStatus.Font = Enum.Font.Code
lblStatus.BackgroundTransparency = 1

local lblCountdown = Instance.new("TextLabel", tabMain)
lblCountdown.Size = UDim2.new(0.9, 0, 0, 20)
lblCountdown.Position = UDim2.new(0.05, 0, 0, 30)
lblCountdown.Text = "Cargo: N/A"
lblCountdown.TextColor3 = Theme.Text
lblCountdown.Font = Enum.Font.Code
lblCountdown.BackgroundTransparency = 1

local btnStart = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 60), "Start")
local btnPause = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 95), "Pause")
local btnForceUnload = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 130), "Force Unload")

local lblDrill = Instance.new("TextLabel", tabMods)
lblDrill.Size = UDim2.new(0.9, 0, 0, 20)
lblDrill.Position = UDim2.new(0.05, 0, 0, 10)
lblDrill.Text = "Drill Multiplier:"
lblDrill.TextColor3 = Theme.Text
lblDrill.Font = Enum.Font.Code
lblDrill.BackgroundTransparency = 1
lblDrill.TextXAlignment = Enum.TextXAlignment.Left

local txtDrillSize = createUIElement("TextBox", tabMods, UDim2.new(0.05, 0, 0, 30), "1")
txtDrillSize.PlaceholderText = "1"
txtDrillSize.ClearTextOnFocus = false

local lblSpeed = Instance.new("TextLabel", tabMods)
lblSpeed.Size = UDim2.new(0.9, 0, 0, 20)
lblSpeed.Position = UDim2.new(0.05, 0, 0, 70)
lblSpeed.Text = "WalkSpeed:"
lblSpeed.TextColor3 = Theme.Text
lblSpeed.Font = Enum.Font.Code
lblSpeed.BackgroundTransparency = 1
lblSpeed.TextXAlignment = Enum.TextXAlignment.Left

local txtWalkSpeed = createUIElement("TextBox", tabMods, UDim2.new(0.05, 0, 0, 90), "16")
txtWalkSpeed.PlaceholderText = "16"
txtWalkSpeed.ClearTextOnFocus = false

local btnTpPlot = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 15), "TP to Plot")
local btnAntiLag = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 50), "Anti-Lag")
local btnTerminate = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 200), "Terminate")

local function switchTab(tabName)
    btnTabMain.BackgroundColor3 = Theme.TabBG
    btnTabMods.BackgroundColor3 = Theme.TabBG
    btnTabMisc.BackgroundColor3 = Theme.TabBG
    
    tabMain.Visible = false
    tabMods.Visible = false
    tabMisc.Visible = false
    
    if tabName == "Main" then
        btnTabMain.BackgroundColor3 = Theme.Active
        tabMain.Visible = true
    elseif tabName == "Mods" then
        btnTabMods.BackgroundColor3 = Theme.Active
        tabMods.Visible = true
    elseif tabName == "Misc" then
        btnTabMisc.BackgroundColor3 = Theme.Active
        tabMisc.Visible = true
    end
end

btnTabMain.MouseButton1Click:Connect(function() switchTab("Main") end)
btnTabMods.MouseButton1Click:Connect(function() switchTab("Mods") end)
btnTabMisc.MouseButton1Click:Connect(function() switchTab("Misc") end)

-- ==========================================
-- 2. Helper Functions
-- ==========================================
local function pressKey(keyCode, delayTime)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(delayTime or 0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function holdKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
end

local function releaseKey(keyCode)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function teleport(cframe)
    local hrp = getHRP()
    if hrp and cframe then
        hrp.CFrame = cframe
        task.wait(0.1)
    end
end

local function safeWait(waitTime)
    local elapsed = 0
    while elapsed < waitTime do
        if not isRunning then break end
        
        if isPaused then
            local prevStatus = lblStatus.Text
            lblStatus.Text = "Status: PAUSED"
            releaseKey(Enum.KeyCode.W)
            releaseKey(Enum.KeyCode.S)
            
            repeat task.wait(0.2) until not isPaused or not isRunning
            
            if not isRunning then break end
            lblStatus.Text = prevStatus
            
            if string.find(prevStatus, "Mining") or string.find(prevStatus, "Drive") then
                holdKey(Enum.KeyCode.W)
            elseif string.find(prevStatus, "Backing") then
                holdKey(Enum.KeyCode.S)
            end
        end
        
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end
end

local function getUnloaderCFrame()
    pcall(function()
        local fgi = workspace:FindFirstChild("FactoryGridItemsClient")
        if not fgi then return end
        
        local pFolder1 = fgi:FindFirstChild(player.Name)
        if not pFolder1 then return end
        
        local pFolder2 = pFolder1:FindFirstChild(player.Name)
        if not pFolder2 then return end
        
        for _, child in ipairs(pFolder2:GetChildren()) do
            if string.find(string.lower(child.Name), "unloader") then
                local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then
                    wp1 = prompt.Parent.CFrame + Vector3.new(0, 3, 0)
                    return
                end
                
                wp1 = child:GetPivot() + Vector3.new(0, 3, 0)
                return
            end
        end
    end)
    return wp1
end

-- TARGETED VEHICLE SCANNER - FIXED WITH DIRECT CHILD COUNT
local function getVehicleCargoData()
    local isFull = false
    local cargoText = nil
    
    pcall(function()
        local vehiclesFolder = workspace:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, vehicle in ipairs(vehiclesFolder:GetChildren()) do
                if vehicle:IsA("Model") then
                    
                    -- PRIMARY CHECK: Look for CargoVolume folder
                    local cargoVolume = vehicle:FindFirstChild("CargoVolume")
                    if cargoVolume then
                        -- Verify the CargoVolume belongs to the player
                        local ownerID = cargoVolume:GetAttribute("OwnerID") or cargoVolume:GetAttribute("Owner")
                        
                        if ownerID == player.UserId or ownerID == player.Name then
                            -- Count ALL direct children in CargoVolume
                            local childCount = #cargoVolume:GetChildren()
                            
                            -- If we have 240 children, cargo is FULL
                            if childCount >= 240 then
                                isFull = true
                            end
                            
                            -- Calculate estimated ore count
                            local estimatedOres = math.floor(childCount / 2)
                            if estimatedOres > VEHICLE_CAPACITY then 
                                estimatedOres = VEHICLE_CAPACITY 
                            end
                            
                            cargoText = tostring(estimatedOres) .. " / " .. tostring(VEHICLE_CAPACITY) .. " [" .. tostring(childCount) .. "]"
                            return 
                        end
                    end
                    
                    -- SECONDARY CHECK: Attributes-based cargo system
                    local current = vehicle:GetAttribute("StoredOres") or vehicle:GetAttribute("Cargo") or vehicle:GetAttribute("OreCount")
                    local maxCap = vehicle:GetAttribute("Capacity") or vehicle:GetAttribute("MaxCapacity")
                    local vehicleOwner = vehicle:GetAttribute("OwnerID") or vehicle:GetAttribute("Owner")
                    
                    if current and maxCap and tonumber(maxCap) == VEHICLE_CAPACITY then
                        if vehicleOwner == player.UserId or vehicleOwner == player.Name then
                            cargoText = tostring(current) .. " / " .. tostring(maxCap)
                            if tonumber(current) >= tonumber(maxCap) then isFull = true end
                            return
                        end
                    end
                end
            end
        end
    end)
    
    return isFull, cargoText
end

-- ==========================================
-- 3. Core Logic
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Unload Cycle..."
    
    pressKey(Enum.KeyCode.E, 0.1)
    safeWait(0.28)
    
    local hrp = getHRP()
    if hrp then wp2 = hrp.CFrame end
    
    for i = 1, 4 do
        teleport(wp1)
        safeWait(0.18)
        pressKey(Enum.KeyCode.E, 0.1)
        safeWait(0.28)
        
        teleport(wp2)
        safeWait(0.18)
        if i < 4 then
            pressKey(Enum.KeyCode.E, 0.1)
            safeWait(0.28)
        end
    end

    lblStatus.Text = "Status: Walking..."
    holdKey(Enum.KeyCode.W)
    safeWait(2) 
    releaseKey(Enum.KeyCode.W)
    
    safeWait(0.28)
    pressKey(Enum.KeyCode.E, 0.1) 
end

local function mineFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Mining..."
    lblCountdown.Text = "Cargo: Checking..."
    
    holdKey(Enum.KeyCode.W)
    
    while isRunning do
        local isFull, cargoText = getVehicleCargoData()
        
        if cargoText then
            lblCountdown.Text = "Cargo: " .. cargoText
        end
        
        safeWait(0.5) 
        
        if forceUnloadTrigger or isFull then
            forceUnloadTrigger = false
            break
        end
    end
    
    releaseKey(Enum.KeyCode.W)
    if not isRunning then return end
    
    task.wait(0.1)
    
    lblStatus.Text = "Status: Exiting..."
    pressKey(Enum.KeyCode.Space, 0.1)
    safeWait(0.5)
    
    lblStatus.Text = "Status: Backing up..."
    holdKey(Enum.KeyCode.S)
    safeWait(2.5) 
    releaseKey(Enum.KeyCode.S)
end

local function mainLoop()
    loopActive = true
    while isRunning do
        mineFunc()
        if not isRunning then break end
        unloadFunc()
        task.wait(0.1)
    end
    lblStatus.Text = "Status: Idle"
    lblCountdown.Text = "Cargo: N/A"
    loopActive = false
end

local minimized = false
btnMinimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        frame.Size = UDim2.new(0, 220, 0, 30)
        contentFrame.Visible = false
        tabBar.Visible = false
        btnMinimize.Text = "+"
    else
        frame.Size = UDim2.new(0, 220, 0, 300)
        contentFrame.Visible = true
        tabBar.Visible = true
        btnMinimize.Text = "-"
    end
end)

local function startScript()
    getUnloaderCFrame()
    
    if not wp1 then
        btnStart.Text = "Unloader Not Found!"
        task.wait(1.5)
        if not isRunning then btnStart.Text = "Start" end
        return
    end
    
    btnStart.Text = "Running..."
    
    if not isRunning then
        isRunning = true
        isPaused = false
        forceUnloadTrigger = false
        task.spawn(mainLoop)
    end
end
btnStart.MouseButton1Click:Connect(startScript)

btnPause.MouseButton1Click:Connect(function()
    if not isRunning then return end
    isPaused = not isPaused
    if isPaused then
        btnPause.Text = "Resume"
    else
        btnPause.Text = "Pause"
    end
end)

btnForceUnload.MouseButton1Click:Connect(function()
    if isRunning then
        forceUnloadTrigger = true
        lblStatus.Text = "Status: Forcing Unload..."
    else
        getUnloaderCFrame()
        if not wp1 then
            btnForceUnload.Text = "Unloader Not Found!"
            task.wait(1.5)
            btnForceUnload.Text = "Force Unload"
            return
        end
        isRunning = true
        task.spawn(function()
            unloadFunc()
            isRunning = false
            lblStatus.Text = "Status: Idle"
            lblCountdown.Text = "Cargo: N/A"
        end)
    end
end)

btnTpPlot.MouseButton1Click:Connect(function()
    local plotId = player:GetAttribute("Plot") or player:GetAttribute("PlotID")
    local plotsFolder = workspace:FindFirstChild("Plots")
    
    if plotsFolder and plotId then
        local targetPlot = plotsFolder:FindFirstChild(tostring(plotId))
        if targetPlot then
            teleport(targetPlot:GetPivot() + Vector3.new(0, 10, 0))
            lblStatus.Text = "Status: TP'd!"
        end
    end
end)

btnAntiLag.MouseButton1Click:Connect(function()
    lblStatus.Text = "Applying Anti-Lag..."
    task.spawn(function()
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        lblStatus.Text = "Anti-Lag Done!"
    end)
end)

local function terminateScript()
    isRunning = false
    isPaused = false
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.S)
    screenGui:Destroy()
end

btnTerminate.MouseButton1Click:Connect(terminateScript)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.Zero then
            startScript()
        elseif input.KeyCode == Enum.KeyCode.LeftControl then
            screenGui.Enabled = not screenGui.Enabled
        end
    end
end)

print("✓ Auto Farm Script Loaded")
