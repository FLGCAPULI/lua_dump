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
local targetedVehicle = nil

-- ANTI-AFK (On by default)
player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- CONFIGURATION
local VEHICLE_CAPACITY = 120 
local MAX_CARGO_CHILDREN = 240 -- The exact number of instances in CargoVolume when full

-- ==========================================
-- 1. GUI Setup (Executor Safe & Redesigned)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmGUI"
screenGui.ResetOnSpawn = false

local success = pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
if not success then screenGui.Parent = player:WaitForChild("PlayerGui") end

-- Shared Theme Colors
local Theme = {
    BG = Color3.fromRGB(30, 30, 30),
    TabBG = Color3.fromRGB(20, 20, 20),
    Button = Color3.fromRGB(45, 45, 45),
    ButtonHover = Color3.fromRGB(60, 60, 60),
    Text = Color3.fromRGB(220, 220, 220),
    Active = Color3.fromRGB(80, 80, 80)
}

-- Frame
local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 280, 0, 400)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Theme.BG
frame.ClipsDescendants = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

-- Topbar
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

-- Tab Bar
local tabBar = Instance.new("Frame", frame)
tabBar.Size = UDim2.new(1, 0, 0, 25)
tabBar.Position = UDim2.new(0, 0, 0, 30)
tabBar.BackgroundColor3 = Theme.TabBG
tabBar.BorderSizePixel = 0

local function createTabBtn(text, pos, widthStr)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size = UDim2.new(widthStr, 0, 1, 0)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Theme.TabBG
    btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.Code
    btn.BorderSizePixel = 0
    btn.TextSize = 11
    return btn
end

-- 3 Tabs now (Main, Mods, Misc) spread evenly
local btnTabMain = createTabBtn("Main", UDim2.new(0, 0, 0, 0), 0.334)
local btnTabMods = createTabBtn("Mods", UDim2.new(0.334, 0, 0, 0), 0.333)
local btnTabMisc = createTabBtn("Misc", UDim2.new(0.667, 0, 0, 0), 0.333)
btnTabMain.BackgroundColor3 = Theme.Active -- Default active

-- Content Container with Scroll
local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, 0, 1, -55)
contentFrame.Position = UDim2.new(0, 0, 0, 55)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true

local scrolling = Instance.new("ScrollingFrame", contentFrame)
scrolling.Size = UDim2.new(1, 0, 1, 0)
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.CanvasSize = UDim2.new(0, 0, 0, 800)
scrolling.ScrollBarThickness = 6

local tabMain = Instance.new("Frame", scrolling)
tabMain.Size = UDim2.new(1, 0, 1, 0)
tabMain.BackgroundTransparency = 1

local tabMods = Instance.new("Frame", scrolling)
tabMods.Size = UDim2.new(1, 0, 1, 0)
tabMods.BackgroundTransparency = 1
tabMods.Visible = false

local tabMisc = Instance.new("Frame", scrolling)
tabMisc.Size = UDim2.new(1, 0, 1, 0)
tabMisc.BackgroundTransparency = 1
tabMisc.Visible = false

-- Helper to create rounded buttons/inputs
local function createUIElement(className, parent, pos, text)
    local el = Instance.new(className, parent)
    el.Size = UDim2.new(0.9, 0, 0, 28)
    el.Position = pos
    el.Text = text
    el.BackgroundColor3 = Theme.Button
    el.TextColor3 = Theme.Text
    el.Font = Enum.Font.Code
    el.TextSize = 12
    Instance.new("UICorner", el).CornerRadius = UDim.new(0, 6)
    return el
end

-- === MAIN TAB ELEMENTS ===

-- Vehicle Selector
local lblTargetTitle = Instance.new("TextLabel", tabMain)
lblTargetTitle.Size = UDim2.new(0.9, 0, 0, 20)
lblTargetTitle.Position = UDim2.new(0.05, 0, 0, 5)
lblTargetTitle.Text = "Target Vehicle:"
lblTargetTitle.TextColor3 = Color3.fromRGB(255, 200, 100)
lblTargetTitle.Font = Enum.Font.Code
lblTargetTitle.BackgroundTransparency = 1
lblTargetTitle.TextXAlignment = Enum.TextXAlignment.Left
lblTargetTitle.TextSize = 12

local btnPrevVeh = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 25), "<")
btnPrevVeh.Size = UDim2.new(0.15, 0, 0, 24)

local lblSelectedVeh = Instance.new("TextLabel", tabMain)
lblSelectedVeh.Size = UDim2.new(0.55, 0, 0, 24)
lblSelectedVeh.Position = UDim2.new(0.225, 0, 0, 25)
lblSelectedVeh.Text = "None"
lblSelectedVeh.TextColor3 = Color3.fromRGB(100, 255, 100)
lblSelectedVeh.Font = Enum.Font.Code
lblSelectedVeh.BackgroundTransparency = 1
lblSelectedVeh.TextSize = 12
lblSelectedVeh.TextScaled = true

local btnNextVeh = createUIElement("TextButton", tabMain, UDim2.new(0.8, 0, 0, 25), ">")
btnNextVeh.Size = UDim2.new(0.15, 0, 0, 24)

-- Drill Multiplier
local lblDrill = Instance.new("TextLabel", tabMain)
lblDrill.Size = UDim2.new(0.9, 0, 0, 20)
lblDrill.Position = UDim2.new(0.05, 0, 0, 55)
lblDrill.Text = "Drill Multiplier (e.g. 5):"
lblDrill.TextColor3 = Theme.Text
lblDrill.Font = Enum.Font.Code
lblDrill.BackgroundTransparency = 1
lblDrill.TextXAlignment = Enum.TextXAlignment.Left

local txtDrillSize = createUIElement("TextBox", tabMain, UDim2.new(0.05, 0, 0, 75), "1")
txtDrillSize.PlaceholderText = "1"
txtDrillSize.ClearTextOnFocus = false

-- Status & Main Buttons
local lblStatus = Instance.new("TextLabel", tabMain)
lblStatus.Size = UDim2.new(0.9, 0, 0, 20)
lblStatus.Position = UDim2.new(0.05, 0, 0, 115)
lblStatus.Text = "Status: Idle"
lblStatus.TextColor3 = Theme.Text
lblStatus.Font = Enum.Font.Code
lblStatus.BackgroundTransparency = 1
lblStatus.TextSize = 12
lblStatus.TextXAlignment = Enum.TextXAlignment.Left

local lblCountdown = Instance.new("TextLabel", tabMain)
lblCountdown.Size = UDim2.new(0.9, 0, 0, 20)
lblCountdown.Position = UDim2.new(0.05, 0, 0, 135)
lblCountdown.Text = "Cargo: N/A"
lblCountdown.TextColor3 = Theme.Text
lblCountdown.Font = Enum.Font.Code
lblCountdown.BackgroundTransparency = 1
lblCountdown.TextSize = 12
lblCountdown.TextXAlignment = Enum.TextXAlignment.Left

local btnStart = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 165), "Start")
local btnPause = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 200), "Pause")
local btnForceUnload = createUIElement("TextButton", tabMain, UDim2.new(0.05, 0, 0, 235), "Force Unload")

-- === MODS TAB ELEMENTS ===
local lblSpeed = Instance.new("TextLabel", tabMods)
lblSpeed.Size = UDim2.new(0.9, 0, 0, 20)
lblSpeed.Position = UDim2.new(0.05, 0, 0, 10)
lblSpeed.Text = "WalkSpeed (e.g. 64):"
lblSpeed.TextColor3 = Theme.Text
lblSpeed.Font = Enum.Font.Code
lblSpeed.BackgroundTransparency = 1
lblSpeed.TextXAlignment = Enum.TextXAlignment.Left

local txtWalkSpeed = createUIElement("TextBox", tabMods, UDim2.new(0.05, 0, 0, 30), "16")
txtWalkSpeed.PlaceholderText = "16"
txtWalkSpeed.ClearTextOnFocus = false

-- === MISC TAB ELEMENTS ===
local btnTpPlot = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 15), "TP to Plot")
local btnExplode = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 50), "Spawn Explosion")
local btnAntiLag = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 85), "Anti-Lag (Boost FPS)")
local btnTerminate = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 200), "Terminate")

-- Tab Switching Logic
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
-- 2. Vehicle Selector Logic
-- ==========================================
local currentVehicleIndex = 0
local vehicleList = {}

local function refreshVehicleList()
    vehicleList = {}
    local vehiclesFolder = workspace:FindFirstChild("Vehicles")
    if vehiclesFolder then
        for _, v in ipairs(vehiclesFolder:GetChildren()) do
            if v:IsA("Model") then
                table.insert(vehicleList, v)
            end
        end
    end
end

local function updateVehicleSelection()
    if #vehicleList == 0 then
        targetedVehicle = nil
        lblSelectedVeh.Text = "None Found"
        lblSelectedVeh.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        if currentVehicleIndex < 1 then currentVehicleIndex = #vehicleList end
        if currentVehicleIndex > #vehicleList then currentVehicleIndex = 1 end
        
        targetedVehicle = vehicleList[currentVehicleIndex]
        lblSelectedVeh.Text = targetedVehicle.Name
        lblSelectedVeh.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

btnPrevVeh.MouseButton1Click:Connect(function()
    refreshVehicleList()
    currentVehicleIndex = currentVehicleIndex - 1
    updateVehicleSelection()
end)

btnNextVeh.MouseButton1Click:Connect(function()
    refreshVehicleList()
    currentVehicleIndex = currentVehicleIndex + 1
    updateVehicleSelection()
end)

-- Initial Auto-Scan for vehicles
task.spawn(function()
    task.wait(1)
    refreshVehicleList()
    if #vehicleList > 0 then
        currentVehicleIndex = 1
        updateVehicleSelection()
    end
end)

-- ==========================================
-- 3. Helper Functions & Scanners
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

-- DYNAMIC UNLOADER SCANNER
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

-- TARGETED VEHICLE SCANNER
local function getVehicleCargoData()
    local isFull = false
    local cargoText = nil
    
    pcall(function()
        if targetedVehicle and targetedVehicle.Parent then
            local vehicle = targetedVehicle
            
            local cargoVolume = vehicle:FindFirstChild("CargoVolume")
            if cargoVolume then
                local currentCount = #cargoVolume:GetChildren()
                local estimatedOres = math.floor(currentCount / (MAX_CARGO_CHILDREN / VEHICLE_CAPACITY))
                if estimatedOres > VEHICLE_CAPACITY then estimatedOres = VEHICLE_CAPACITY end
                
                cargoText = tostring(estimatedOres) .. " / " .. tostring(VEHICLE_CAPACITY) .. " [Raw: " .. tostring(currentCount) .. "]"
                if currentCount >= MAX_CARGO_CHILDREN then isFull = true end
                return 
            end
            
            local current = vehicle:GetAttribute("StoredOres") or vehicle:GetAttribute("Cargo") or vehicle:GetAttribute("OreCount")
            local maxCap = vehicle:GetAttribute("Capacity") or vehicle:GetAttribute("MaxCapacity")
            
            if current and maxCap then
                cargoText = tostring(current) .. " / " .. tostring(maxCap)
                if tonumber(current) >= tonumber(maxCap) then isFull = true end
                return
            end
        end
    end)
    
    return isFull, cargoText
end

-- ==========================================
-- 4. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Cargo: N/A"
    
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

    lblStatus.Text = "Status: Walking to Drive..."
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
        else
            lblCountdown.Text = "Cargo: Target missing!"
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
    
    lblStatus.Text = "Status: Exiting Vehicle..."
    pressKey(Enum.KeyCode.Space, 0.1)
    safeWait(0.5)
    
    lblStatus.Text = "Status: Backing up..."
    holdKey(Enum.KeyCode.S)
    safeWait(2.5) 
    releaseKey(Enum.KeyCode.S)
end

-- ==========================================
-- MODIFIERS (Read from TextBoxes)
-- ==========================================
local function applyDrillSizeMulti()
    local multi = tonumber(txtDrillSize.Text) or 1
    
    pcall(function()
        if targetedVehicle and targetedVehicle.Parent then
            local body = targetedVehicle:FindFirstChild("Body")
            local drillZone = body and body:FindFirstChild("DrillZone")
            
            -- Fallback deep search if not found in Body
            if not drillZone then
                drillZone = targetedVehicle:FindFirstChild("DrillZone", true)
            end
            
            if drillZone and drillZone:IsA("BasePart") then
                if not drillZone:GetAttribute("OriginalSize") then
                    drillZone:SetAttribute("OriginalSize", drillZone.Size)
                end
                
                local origSize = drillZone:GetAttribute("OriginalSize")
                drillZone.Size = origSize * multi
                
                if multi > 1 then
                    drillZone.Transparency = 0.5
                else
                    drillZone.Transparency = 1
                end
            end
        end
    end)
end

local function applyWalkSpeed()
    local speed = tonumber(txtWalkSpeed.Text) or 16
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = speed
        end
    end
end

-- Apply modifications periodically
task.spawn(function()
    while task.wait(0.5) do
        applyDrillSizeMulti()
        
        local speed = tonumber(txtWalkSpeed.Text)
        if speed and speed ~= 16 then
            applyWalkSpeed()
        end
    end
end)

-- ==========================================
-- 5. Main Loop & Events
-- ==========================================
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
        frame.Size = UDim2.new(0, 280, 0, 30)
        scrolling.Visible = false
        tabBar.Visible = false
        btnMinimize.Text = "+"
    else
        frame.Size = UDim2.new(0, 280, 0, 400)
        scrolling.Visible = true
        tabBar.Visible = true
        btnMinimize.Text = "-"
    end
end)

local function startScript()
    if not targetedVehicle then
        btnStart.Text = "Select a Vehicle First!"
        task.wait(1.5)
        if not isRunning then btnStart.Text = "Start" end
        return
    end

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
    local plotId = player:GetAttribute("Plot") or player:GetAttribute("PlotID") or player:GetAttribute("PlotId") or player:GetAttribute("plot")
    
    if not plotId then
        local plotVal = player:FindFirstChild("Plot") or player:FindFirstChild("PlotID") or player:FindFirstChild("PlotId")
        if plotVal then plotId = plotVal.Value end
    end

    local plotsFolder = workspace:FindFirstChild("Plots")
    local targetPlot = nil

    if plotsFolder then
        if plotId then targetPlot = plotsFolder:FindFirstChild(tostring(plotId)) end

        if not targetPlot then
            for _, plot in ipairs(plotsFolder:GetChildren()) do
                local ownerAttr = plot:GetAttribute("Owner") or plot:GetAttribute("OwnerId") or plot:GetAttribute("Player")
                if ownerAttr == player.Name or ownerAttr == player.UserId then
                    targetPlot = plot
                    break
                end
                
                local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("OwnerId")
                if ownerVal and (ownerVal.Value == player.Name or ownerVal.Value == player.UserId) then
                    targetPlot = plot
                    break
                end
            end
        end

        if targetPlot then
            local targetCFrame = targetPlot:GetPivot()
            if targetCFrame then
                teleport(targetCFrame + Vector3.new(0, 10, 0))
                lblStatus.Text = "Status: TP'd to Plot!"
            end
        else
            lblStatus.Text = "Status: Plot ID missing!"
        end
    else
        lblStatus.Text = "Status: Plots folder missing!"
    end
end)

btnExplode.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then
        local explosion = Instance.new("Explosion")
        explosion.Name = "Explosion"
        explosion.BlastPressure = 10000
        explosion.BlastRadius = 60
        explosion.DestroyJointRadiusPercent = 0
        explosion.ExplosionType = Enum.ExplosionType.NoCraters
        explosion.Position = hrp.Position
        explosion.Parent = workspace
        
        lblStatus.Text = "Status: Boom!"
    else
        lblStatus.Text = "Status: Spawn First!"
    end
end)

btnAntiLag.MouseButton1Click:Connect(function()
    lblStatus.Text = "Status: Applying Anti-Lag..."
    task.spawn(function()
        local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass('Terrain')
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
        end
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                obj.Transparency = 1
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                obj.Lifetime = NumberRange.new(0)
            end
        end
        lblStatus.Text = "Status: Anti-Lag Applied!"
    end)
end)

local function terminateScript()
    isRunning = false
    isPaused = false
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.S)
    screenGui:Destroy()
    print("Script Terminated.")
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
