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

-- Tabs (Now 4 sections)
local btnTabMain = createTabBtn("Vehicle", UDim2.new(0, 0, 0, 0), 0.25)
local btnTabPlayer = createTabBtn("Player", UDim2.new(0.25, 0, 0, 0), 0.25)
local btnTabMods = createTabBtn("Mods", UDim2.new(0.5, 0, 0, 0), 0.25)
local btnTabMisc = createTabBtn("Misc", UDim2.new(0.75, 0, 0, 0), 0.25)
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

local tabPlayer = Instance.new("Frame", scrolling)
tabPlayer.Size = UDim2.new(1, 0, 1, 0)
tabPlayer.BackgroundTransparency = 1
tabPlayer.Visible = false

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

-- === PLAYER (ORE FARM) TAB ELEMENTS ===
local lblMaxOre = Instance.new("TextLabel", tabPlayer)
lblMaxOre.Size = UDim2.new(0.9, 0, 0, 20)
lblMaxOre.Position = UDim2.new(0.05, 0, 0, 5)
lblMaxOre.Text = "Max Ores Before Unload:"
lblMaxOre.TextColor3 = Theme.Text
lblMaxOre.Font = Enum.Font.Code
lblMaxOre.BackgroundTransparency = 1
lblMaxOre.TextXAlignment = Enum.TextXAlignment.Left

local txtMaxOre = createUIElement("TextBox", tabPlayer, UDim2.new(0.05, 0, 0, 25), "50")
txtMaxOre.PlaceholderText = "50"
txtMaxOre.ClearTextOnFocus = false

local btnToggleAutoUnload = createUIElement("TextButton", tabPlayer, UDim2.new(0.05, 0, 0, 60), "Auto Unload: OFF")
local lblPlayerCargo = Instance.new("TextLabel", tabPlayer)
lblPlayerCargo.Size = UDim2.new(0.9, 0, 0, 20)
lblPlayerCargo.Position = UDim2.new(0.05, 0, 0, 95)
lblPlayerCargo.Text = "Backpack: 0 / 50"
lblPlayerCargo.TextColor3 = Theme.Text
lblPlayerCargo.Font = Enum.Font.Code
lblPlayerCargo.BackgroundTransparency = 1
lblPlayerCargo.TextSize = 12
lblPlayerCargo.TextXAlignment = Enum.TextXAlignment.Left

local btnToggleAutoFarm = createUIElement("TextButton", tabPlayer, UDim2.new(0.05, 0, 0, 125), "Auto TP Farm: OFF")

local lblAuraRadius = Instance.new("TextLabel", tabPlayer)
lblAuraRadius.Size = UDim2.new(0.9, 0, 0, 20)
lblAuraRadius.Position = UDim2.new(0.05, 0, 0, 160)
lblAuraRadius.Text = "Ore Aura Radius (Studs):"
lblAuraRadius.TextColor3 = Theme.Text
lblAuraRadius.Font = Enum.Font.Code
lblAuraRadius.BackgroundTransparency = 1
lblAuraRadius.TextXAlignment = Enum.TextXAlignment.Left

local txtAuraRadius = createUIElement("TextBox", tabPlayer, UDim2.new(0.05, 0, 0, 180), "15")
txtAuraRadius.PlaceholderText = "15"
txtAuraRadius.ClearTextOnFocus = false

local btnToggleOreAura = createUIElement("TextButton", tabPlayer, UDim2.new(0.05, 0, 0, 215), "Ore Aura: OFF")

local lblPlayerStatus = Instance.new("TextLabel", tabPlayer)
lblPlayerStatus.Size = UDim2.new(0.9, 0, 0, 20)
lblPlayerStatus.Position = UDim2.new(0.05, 0, 0, 250)
lblPlayerStatus.Text = "Status: Idle"
lblPlayerStatus.TextColor3 = Theme.Text
lblPlayerStatus.Font = Enum.Font.Code
lblPlayerStatus.BackgroundTransparency = 1
lblPlayerStatus.TextSize = 12
lblPlayerStatus.TextXAlignment = Enum.TextXAlignment.Left

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

-- === NEW: EVASION TOGGLE & SETTINGS ===
local evasionEnabled = true

local btnToggleEvasion = createUIElement("TextButton", tabMods, UDim2.new(0.05, 0, 0, 70), "Auto-Evasion: ON")
btnToggleEvasion.BackgroundColor3 = Color3.fromRGB(100, 150, 100)

local lblEvasionAngle = Instance.new("TextLabel", tabMods)
lblEvasionAngle.Size = UDim2.new(0.9, 0, 0, 20)
lblEvasionAngle.Position = UDim2.new(0.05, 0, 0, 110)
lblEvasionAngle.Text = "Evasion Angle (Deg):"
lblEvasionAngle.TextColor3 = Theme.Text
lblEvasionAngle.Font = Enum.Font.Code
lblEvasionAngle.BackgroundTransparency = 1
lblEvasionAngle.TextXAlignment = Enum.TextXAlignment.Left

local txtEvasionAngle = createUIElement("TextBox", tabMods, UDim2.new(0.05, 0, 0, 130), "60")
txtEvasionAngle.PlaceholderText = "60"
txtEvasionAngle.ClearTextOnFocus = false

btnToggleEvasion.MouseButton1Click:Connect(function()
    evasionEnabled = not evasionEnabled
    if evasionEnabled then
        btnToggleEvasion.Text = "Auto-Evasion: ON"
        btnToggleEvasion.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    else
        btnToggleEvasion.Text = "Auto-Evasion: OFF"
        btnToggleEvasion.BackgroundColor3 = Theme.Button
    end
end)

-- === NEW: CAMERA/COMPASS OFFSET ===
local lblFrontOffset = Instance.new("TextLabel", tabMods)
lblFrontOffset.Size = UDim2.new(0.9, 0, 0, 20)
lblFrontOffset.Position = UDim2.new(0.05, 0, 0, 170)
lblFrontOffset.Text = "Vehicle Front Offset (Deg):"
lblFrontOffset.TextColor3 = Theme.Text
lblFrontOffset.Font = Enum.Font.Code
lblFrontOffset.BackgroundTransparency = 1
lblFrontOffset.TextXAlignment = Enum.TextXAlignment.Left

-- Changed default from -90 to 90 (if -90 looked left, 90 or 0 should look front!)
local txtFrontOffset = createUIElement("TextBox", tabMods, UDim2.new(0.05, 0, 0, 190), "90")
txtFrontOffset.PlaceholderText = "90"
txtFrontOffset.ClearTextOnFocus = false

local btnTestCam = createUIElement("TextButton", tabMods, UDim2.new(0.05, 0, 0, 230), "Test Camera Alignment")
btnTestCam.BackgroundColor3 = Color3.fromRGB(100, 100, 150)

-- === MISC TAB ELEMENTS ===
local btnTpPlot = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 15), "TP to Plot")
local btnExplode = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 50), "Spawn Explosion")
local btnAntiLag = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 85), "Anti-Lag (Boost FPS)")
local btnTerminate = createUIElement("TextButton", tabMisc, UDim2.new(0.05, 0, 0, 200), "Terminate")

-- Tab Switching Logic
local function switchTab(tabName)
    btnTabMain.BackgroundColor3 = Theme.TabBG
    btnTabPlayer.BackgroundColor3 = Theme.TabBG
    btnTabMods.BackgroundColor3 = Theme.TabBG
    btnTabMisc.BackgroundColor3 = Theme.TabBG
    
    tabMain.Visible = false
    tabPlayer.Visible = false
    tabMods.Visible = false
    tabMisc.Visible = false
    
    if tabName == "Vehicle" then
        btnTabMain.BackgroundColor3 = Theme.Active
        tabMain.Visible = true
    elseif tabName == "Player" then
        btnTabPlayer.BackgroundColor3 = Theme.Active
        tabPlayer.Visible = true
    elseif tabName == "Mods" then
        btnTabMods.BackgroundColor3 = Theme.Active
        tabMods.Visible = true
    elseif tabName == "Misc" then
        btnTabMisc.BackgroundColor3 = Theme.Active
        tabMisc.Visible = true
    end
end

btnTabMain.MouseButton1Click:Connect(function() switchTab("Vehicle") end)
btnTabPlayer.MouseButton1Click:Connect(function() switchTab("Player") end)
btnTabMods.MouseButton1Click:Connect(function() switchTab("Mods") end)
btnTabMisc.MouseButton1Click:Connect(function() switchTab("Misc") end)

-- Wire up the test button so you can calibrate without waiting for the macro
btnTestCam.MouseButton1Click:Connect(function()
    if targetedVehicle then
        alignCameraWithVehicle()
        lblStatus.Text = "Status: Camera Tested!"
    else
        lblStatus.Text = "Status: Select a vehicle first!"
    end
end)

-- ==========================================
-- 2. Vehicle Selector Logic
-- ==========================================
local currentVehicleIndex = 0
local vehicleList = {}

local function getVehicleOwnerName(vehicle)
    if not vehicle then return "Unknown" end
    
    local ownerAttr = vehicle:GetAttribute("Owner") or vehicle:GetAttribute("Player") or vehicle:GetAttribute("Driver")
    if type(ownerAttr) == "string" and ownerAttr ~= "" then
        return ownerAttr
    elseif type(ownerAttr) == "number" then
        local p = Players:GetPlayerByUserId(ownerAttr)
        if p then return p.Name end
        return tostring(ownerAttr)
    end
    
    local ownerVal = vehicle:FindFirstChild("Owner") or vehicle:FindFirstChild("Player") or vehicle:FindFirstChild("Driver")
    if ownerVal then
        if ownerVal:IsA("StringValue") and ownerVal.Value ~= "" then
            return ownerVal.Value
        elseif ownerVal:IsA("ObjectValue") and ownerVal.Value then
            return ownerVal.Value.Name
        end
    end
    
    local seat = vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
    if seat and seat.Occupant and seat.Occupant.Parent then
        return seat.Occupant.Parent.Name
    end
    
    return "Unknown"
end

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
        local ownerName = getVehicleOwnerName(targetedVehicle)
        lblSelectedVeh.Text = targetedVehicle.Name .. " (" .. ownerName .. ")"
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
        
        for i, v in ipairs(vehicleList) do
            local ownerName = getVehicleOwnerName(v)
            if ownerName == player.Name or ownerName == tostring(player.UserId) then
                currentVehicleIndex = i
                break
            end
        end
        
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

-- HELPER TO GET TRUE FORWARD VECTOR (WITH OFFSET FIX)
local function getTrueVehicleLookVector()
    local baseVector = Vector3.new(0, 0, -1)
    
    if targetedVehicle and targetedVehicle.Parent then
        local seat = targetedVehicle:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat then
            baseVector = seat.CFrame.LookVector
        else
            baseVector = targetedVehicle:GetPivot().LookVector
        end
    end
    
    -- Apply Rotation Offset to fix sideway vehicles
    local offsetDeg = tonumber(txtFrontOffset.Text) or 0
    if offsetDeg ~= 0 then
        local rad = math.rad(offsetDeg)
        local cosT = math.cos(rad)
        local sinT = math.sin(rad)
        
        -- Rotate vector around the Y axis
        local rx = baseVector.X * cosT - baseVector.Z * sinT
        local rz = baseVector.X * sinT + baseVector.Z * cosT
        baseVector = Vector3.new(rx, baseVector.Y, rz).Unit
    end
    
    return baseVector
end

-- VEHICLE POSITION SCANNER
local function getVehiclePosition()
    if targetedVehicle and targetedVehicle.Parent then
        return targetedVehicle:GetPivot().Position
    end
    -- Fallback to player position if vehicle isn't locked
    local hrp = getHRP()
    if hrp then return hrp.Position end
    return nil
end

-- VEHICLE HEADING COMPASS
local function getVehicleHeading()
    local lv = getTrueVehicleLookVector()
    -- Calculate yaw angle in degrees (0 to 360)
    local deg = math.deg(math.atan2(lv.X, -lv.Z))
    if deg < 0 then deg = deg + 360 end
    return deg
end

local function getShortestAngle(target, current)
    -- Returns the shortest difference between two angles (-180 to 180)
    return (target - current + 180) % 360 - 180
end

-- ==========================================
-- NEW: PLAYER ORE FARM LOGIC
-- ==========================================
local isAutoUnloading = false
local isAutoFarming = false
local isOreAura = false

local function getOrePackCount()
    local pFolder = workspace:FindFirstChild(player.Name)
    if pFolder then
        local orePack = pFolder:FindFirstChild("OrePackCargo")
        if orePack then
            -- Subtract 1 for the permanent child, then divide by 2 since each ore adds 2 children (ore + weld)
            local rawCount = #orePack:GetChildren()
            local actualOres = math.floor(math.max(0, rawCount - 1) / 2)
            return actualOres
        end
    end
    return 0
end

local function getNearestOre(maxRadius)
    local placedOre = workspace:FindFirstChild("PlacedOre")
    if not placedOre then return nil end
    
    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    
    local closest = nil
    local minDist = maxRadius or math.huge
    
    for _, ore in ipairs(placedOre:GetChildren()) do
        if ore:IsA("BasePart") or ore:IsA("Model") then
            local pos = ore:IsA("Model") and ore:GetPivot().Position or ore.Position
            local dist = (myPos - pos).Magnitude
            if dist <= minDist then
                minDist = dist
                closest = ore
            end
        end
    end
    
    return closest
end

-- SMART RAYCAST CLIPPING FIX
local function getSafeOrePosition(orePos)
    local hrp = getHRP()
    if not hrp then return orePos + Vector3.new(0, 4, 4) end
    local myPos = hrp.Position
    
    local direction = (orePos - myPos).Unit
    local distance = (orePos - myPos).Magnitude
    
    local raycastParams = RaycastParams.new()
    local placedOre = workspace:FindFirstChild("PlacedOre")
    raycastParams.FilterDescendantsInstances = {player.Character, placedOre}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayResult = workspace:Raycast(myPos, direction * distance, raycastParams)
    
    if rayResult then
        -- Stand 4 studs away from the cave wall surface (using normal) to prevent rubberbanding
        return rayResult.Position + (rayResult.Normal * 4) + Vector3.new(0, 1, 0)
    else
        -- Line of sight clear, step back normally
        return orePos - (direction * 3) + Vector3.new(0, 1, 0)
    end
end

-- HELPER FOR SCREEN CENTER CLICKING
local function getScreenCenter()
    local cam = workspace.CurrentCamera
    if cam then
        return cam.ViewportSize / 2
    end
    return Vector2.new()
end

-- 1. AUTO UNLOAD LOOP
task.spawn(function()
    while task.wait(0.5) do
        local currentOres = getOrePackCount()
        local maxOres = tonumber(txtMaxOre.Text) or 50
        lblPlayerCargo.Text = "Backpack: " .. currentOres .. " / " .. maxOres
        
        if isAutoUnloading and currentOres >= maxOres then
            lblPlayerStatus.Text = "Status: Unloading Backpack..."
            local hrp = getHRP()
            local returnPos = hrp and hrp.CFrame
            
            getUnloaderCFrame()
            if wp1 then
                teleport(wp1)
                task.wait(0.3)
                pressKey(Enum.KeyCode.E, 0.1)
                task.wait(2) -- Wait for ores to process
                
                if returnPos then teleport(returnPos) end
            else
                lblPlayerStatus.Text = "Status: Unloader Not Found!"
                task.wait(1.5)
            end
        end
    end
end)

-- 2. AUTO TP FARM LOOP
task.spawn(function()
    while task.wait(0.1) do
        if isAutoFarming then
            -- Pause if we are currently unloading
            if isAutoUnloading and getOrePackCount() >= (tonumber(txtMaxOre.Text) or 50) then
                VirtualUser:Button1Up(getScreenCenter())
                task.wait(1)
                continue
            end
            
            local targetOre = getNearestOre(math.huge)
            local placedOre = workspace:FindFirstChild("PlacedOre")
            
            if targetOre and placedOre then
                lblPlayerStatus.Text = "Status: TP Farming..."
                local orePos = targetOre:IsA("Model") and targetOre:GetPivot().Position or targetOre.Position
                local safePos = getSafeOrePosition(orePos)
                
                teleport(CFrame.lookAt(safePos, orePos))
                
                local cam = workspace.CurrentCamera
                local centerPos = getScreenCenter()
                
                -- Press and hold left click at the center of the screen
                VirtualUser:Button1Down(centerPos)
                VirtualInputManager:SendMouseButtonEvent(centerPos.X, centerPos.Y, 0, true, game, 1)
                
                -- Wait until this specific ore is destroyed or removed from PlacedOre
                while isAutoFarming and targetOre and targetOre.Parent == placedOre do
                    if isAutoUnloading and getOrePackCount() >= (tonumber(txtMaxOre.Text) or 50) then
                        break -- Interrupt to go unload
                    end
                    
                    -- Keep camera locked onto it so the center of the screen hits the ore
                    if cam then cam.CFrame = CFrame.lookAt(cam.CFrame.Position, orePos) end
                    
                    -- Backup activation just in case
                    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
                    if tool then tool:Activate() end
                    
                    task.wait(0.1)
                end
                
                -- Release click when the ore is gone
                VirtualUser:Button1Up(centerPos)
                VirtualInputManager:SendMouseButtonEvent(centerPos.X, centerPos.Y, 0, false, game, 1)
            else
                lblPlayerStatus.Text = "Status: Waiting for Ores..."
                task.wait(1)
            end
        end
    end
end)

-- 3. ORE AURA LOOP
task.spawn(function()
    while task.wait(0.1) do
        if isOreAura then
            local radius = tonumber(txtAuraRadius.Text) or 15
            local targetOre = getNearestOre(radius)
            local placedOre = workspace:FindFirstChild("PlacedOre")
            
            if targetOre and placedOre then
                if not isAutoFarming then lblPlayerStatus.Text = "Status: Aura Mining..." end
                
                local centerPos = getScreenCenter()
                
                -- Press and hold left click
                VirtualUser:Button1Down(centerPos)
                VirtualInputManager:SendMouseButtonEvent(centerPos.X, centerPos.Y, 0, true, game, 1)
                
                -- Wait until the ore is destroyed
                while isOreAura and targetOre and targetOre.Parent == placedOre do
                    local orePos = targetOre:IsA("Model") and targetOre:GetPivot().Position or targetOre.Position
                    local hrp = getHRP()
                    
                    -- Turn character slightly to face ore so the hit registers
                    if hrp then hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(orePos.X, hrp.Position.Y, orePos.Z)) end
                    
                    local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
                    if tool then tool:Activate() end
                    
                    task.wait(0.1)
                    
                    -- If we manually walk away from the ore, break the lock so we don't swing forever
                    if hrp and (hrp.Position - orePos).Magnitude > radius + 5 then
                        break
                    end
                end
                
                -- Release click
                VirtualUser:Button1Up(centerPos)
                VirtualInputManager:SendMouseButtonEvent(centerPos.X, centerPos.Y, 0, false, game, 1)
            else
                if not isAutoFarming then lblPlayerStatus.Text = "Status: Idle" end
            end
        end
    end
end)

-- BUTTON TOGGLES
btnToggleAutoUnload.MouseButton1Click:Connect(function()
    isAutoUnloading = not isAutoUnloading
    if isAutoUnloading then
        btnToggleAutoUnload.Text = "Auto Unload: ON"
        btnToggleAutoUnload.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    else
        btnToggleAutoUnload.Text = "Auto Unload: OFF"
        btnToggleAutoUnload.BackgroundColor3 = Theme.Button
    end
end)

btnToggleAutoFarm.MouseButton1Click:Connect(function()
    isAutoFarming = not isAutoFarming
    if isAutoFarming then
        btnToggleAutoFarm.Text = "Auto TP Farm: ON"
        btnToggleAutoFarm.BackgroundColor3 = Color3.fromRGB(150, 100, 100)
    else
        btnToggleAutoFarm.Text = "Auto TP Farm: OFF"
        btnToggleAutoFarm.BackgroundColor3 = Theme.Button
        lblPlayerStatus.Text = "Status: Idle"
    end
end)

btnToggleOreAura.MouseButton1Click:Connect(function()
    isOreAura = not isOreAura
    if isOreAura then
        btnToggleOreAura.Text = "Ore Aura: ON"
        btnToggleOreAura.BackgroundColor3 = Color3.fromRGB(150, 150, 100)
    else
        btnToggleOreAura.Text = "Ore Aura: OFF"
        btnToggleOreAura.BackgroundColor3 = Theme.Button
        if not isAutoFarming then lblPlayerStatus.Text = "Status: Idle" end
    end
end)


-- CAMERA ALIGNMENT SENSOR
local function alignCameraWithVehicle()
    local camera = workspace.CurrentCamera
    if targetedVehicle and targetedVehicle.Parent and camera then
        local lookDir = getTrueVehicleLookVector()
        
        -- Flatten the Y axis so the camera doesn't look straight into the ground or sky
        local flatLookDir = Vector3.new(lookDir.X, 0, lookDir.Z)
        if flatLookDir.Magnitude > 0.001 then
            flatLookDir = flatLookDir.Unit
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + flatLookDir)
        else
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + lookDir)
        end
    end
end

-- ==========================================
-- 4. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Cargo: N/A"
    
    -- Align camera before starting the unload sequence
    alignCameraWithVehicle()
    task.wait(0.1)
    
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
    
    local lastCheckTime = tick()
    local lastPos = getVehiclePosition()
    
    while isRunning do
        local isFull, cargoText = getVehicleCargoData()
        
        if cargoText then
            lblCountdown.Text = "Cargo: " .. cargoText
        else
            lblCountdown.Text = "Cargo: Target missing!"
        end
        
        if forceUnloadTrigger or isFull then
            forceUnloadTrigger = false
            break
        end
        
        -- ====================================
        -- STUCK DETECTION & EVASION LOGIC
        -- ====================================
        if evasionEnabled and tick() - lastCheckTime >= 2 then
            local currentPos = getVehiclePosition()
            if currentPos and lastPos then
                local dist = (currentPos - lastPos).Magnitude
                
                -- If we moved less than 2 studs in 2 seconds, we are stuck!
                if dist < 2.0 then
                    local dodgeAngle = tonumber(txtEvasionAngle.Text) or 60
                    lblStatus.Text = "Status: Stuck! Reversing..."
                    releaseKey(Enum.KeyCode.W)
                    
                    -- Record original heading before evasion
                    local originalHeading = getVehicleHeading()
                    
                    -- 1. Reverse for 5 seconds
                    holdKey(Enum.KeyCode.S)
                    for _ = 1, 10 do -- 10 * 0.5s = 5 seconds
                        safeWait(0.5)
                        if not isRunning or forceUnloadTrigger then break end
                    end
                    releaseKey(Enum.KeyCode.S)
                    
                    if isRunning and not forceUnloadTrigger then
                        lblStatus.Text = "Status: Dodging Obstacle..."
                        
                        -- Randomly pick a direction to prevent wall hugging
                        local dodgeRight = math.random() > 0.5
                        local turnKey = dodgeRight and Enum.KeyCode.D or Enum.KeyCode.A
                        local counterKey = dodgeRight and Enum.KeyCode.A or Enum.KeyCode.D
                        
                        -- Target heading offset by our 60 degrees (or configured setting)
                        local targetHeading = (originalHeading + (dodgeRight and dodgeAngle or -dodgeAngle)) % 360
                        
                        -- 2. Turn to target angle (using compass)
                        holdKey(turnKey)
                        holdKey(Enum.KeyCode.W)
                        local turnStart = tick()
                        while isRunning and not forceUnloadTrigger and (tick() - turnStart < 5) do -- 5s safety timeout
                            local currentHeading = getVehicleHeading()
                            local diff = math.abs(getShortestAngle(targetHeading, currentHeading))
                            if diff <= 10 then -- Stop when within 10 degrees of target
                                break
                            end
                            task.wait(0.1)
                        end
                        releaseKey(turnKey)
                        
                        -- 3. Drive forward for 10 seconds to bypass
                        local brokeEarly = false
                        for _ = 1, 20 do -- 20 * 0.5s = 10 seconds
                            safeWait(0.5)
                            -- Continuously check cargo so we don't overfill during the 10s drive
                            local currentIsFull, currentCargoText = getVehicleCargoData()
                            if currentCargoText then lblCountdown.Text = "Cargo: " .. currentCargoText end
                            if currentIsFull or forceUnloadTrigger or not isRunning then 
                                brokeEarly = true
                                break 
                            end
                        end
                        
                        -- 4. Turn opposite direction to correct the angle back to original
                        if isRunning and not forceUnloadTrigger and not brokeEarly then
                            lblStatus.Text = "Status: Correcting Angle..."
                            holdKey(counterKey)
                            holdKey(Enum.KeyCode.W)
                            local correctStart = tick()
                            while isRunning and not forceUnloadTrigger and (tick() - correctStart < 5) do
                                local currentHeading = getVehicleHeading()
                                local diff = math.abs(getShortestAngle(originalHeading, currentHeading))
                                if diff <= 10 then -- Stop when within 10 degrees of original heading
                                    break
                                end
                                task.wait(0.1)
                            end
                            releaseKey(counterKey)
                        end
                        
                        lblStatus.Text = "Status: Mining..."
                        holdKey(Enum.KeyCode.W) -- Re-ensure W is held
                    end
                end
            end
            lastPos = currentPos
            lastCheckTime = tick()
        end
        -- ====================================
        
        safeWait(0.5) 
    end
    
    -- Safely release all movement keys just in case we broke out during a dodge
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.A)
    releaseKey(Enum.KeyCode.S)
    releaseKey(Enum.KeyCode.D)
    
    if not isRunning then return end
    
    task.wait(0.1)
    
    -- Make sure camera is aligned with vehicle before exiting
    alignCameraWithVehicle()
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
    isAutoUnloading = false
    isAutoFarming = false
    isOreAura = false
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.A)
    releaseKey(Enum.KeyCode.S)
    releaseKey(Enum.KeyCode.D)
    
    local centerPos = getScreenCenter()
    VirtualUser:Button1Up(centerPos)
    VirtualInputManager:SendMouseButtonEvent(centerPos.X, centerPos.Y, 0, false, game, 1)
    
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
