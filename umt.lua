local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Wait securely for the player to exist (fixes auto-execute bugs)
local player = Players.LocalPlayer
while not player do
    task.wait(0.1)
    player = Players.LocalPlayer
end

-- Helper to dynamically get HRP so the script doesn't break when you die/respawn
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

-- CONFIGURATION
local VEHICLE_CAPACITY = 120 
local MAX_CARGO_CHILDREN = 240 -- The exact number of instances in CargoVolume when full (120 ores * 2 parts/welds)

-- ==========================================
-- 1. GUI Setup (Executor Safe)
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmGUI"
screenGui.ResetOnSpawn = false

-- Safely attempt to parent to CoreGui without triggering security exceptions at the top level
local success = pcall(function()
    screenGui.Parent = game:GetService("CoreGui")
end)
if not success then 
    screenGui.Parent = player:WaitForChild("PlayerGui") 
end

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 450) -- Increased height to fit Explosion button
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.ClipsDescendants = true

local topbar = Instance.new("Frame", frame)
topbar.Size = UDim2.new(1, 0, 0, 30)
topbar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)

local title = Instance.new("TextLabel", topbar)
title.Size = UDim2.new(0.8, 0, 1, 0)
title.Position = UDim2.new(0.05, 0, 0, 0)
title.Text = "Auto Farm Script"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1

local btnMinimize = Instance.new("TextButton", topbar)
btnMinimize.Size = UDim2.new(0.2, 0, 1, 0)
btnMinimize.Position = UDim2.new(0.8, 0, 0, 0)
btnMinimize.Text = "-"
btnMinimize.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
btnMinimize.TextColor3 = Color3.new(1, 1, 1)

local contentFrame = Instance.new("Frame", frame)
contentFrame.Size = UDim2.new(1, 0, 1, -30)
contentFrame.Position = UDim2.new(0, 0, 0, 30)
contentFrame.BackgroundTransparency = 1

local lblStatus = Instance.new("TextLabel", contentFrame)
lblStatus.Size = UDim2.new(0.9, 0, 0, 20)
lblStatus.Position = UDim2.new(0.05, 0, 0, 10)
lblStatus.Text = "Status: Idle"
lblStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
lblStatus.BackgroundTransparency = 1

local lblCountdown = Instance.new("TextLabel", contentFrame)
lblCountdown.Size = UDim2.new(0.9, 0, 0, 20)
lblCountdown.Position = UDim2.new(0.05, 0, 0, 30)
lblCountdown.Text = "Time: 0s"
lblCountdown.TextColor3 = Color3.fromRGB(200, 200, 200)
lblCountdown.BackgroundTransparency = 1

local btnSetWp1 = Instance.new("TextButton", contentFrame)
btnSetWp1.Size = UDim2.new(0.9, 0, 0, 30)
btnSetWp1.Position = UDim2.new(0.05, 0, 0, 60)
btnSetWp1.Text = "Set WP 1"
btnSetWp1.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
btnSetWp1.TextColor3 = Color3.new(1, 1, 1)

local btnStart = Instance.new("TextButton", contentFrame)
btnStart.Size = UDim2.new(0.9, 0, 0, 30)
btnStart.Position = UDim2.new(0.05, 0, 0, 100)
btnStart.Text = "Start"
btnStart.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
btnStart.TextColor3 = Color3.new(1, 1, 1)

local btnPause = Instance.new("TextButton", contentFrame)
btnPause.Size = UDim2.new(0.9, 0, 0, 30)
btnPause.Position = UDim2.new(0.05, 0, 0, 140)
btnPause.Text = "Pause"
btnPause.BackgroundColor3 = Color3.fromRGB(150, 100, 20)
btnPause.TextColor3 = Color3.new(1, 1, 1)

local btnForceUnload = Instance.new("TextButton", contentFrame)
btnForceUnload.Size = UDim2.new(0.9, 0, 0, 30)
btnForceUnload.Position = UDim2.new(0.05, 0, 0, 180)
btnForceUnload.Text = "Force Unload"
btnForceUnload.BackgroundColor3 = Color3.fromRGB(120, 60, 150)
btnForceUnload.TextColor3 = Color3.new(1, 1, 1)

local btnDrillSize = Instance.new("TextButton", contentFrame)
btnDrillSize.Size = UDim2.new(0.9, 0, 0, 30)
btnDrillSize.Position = UDim2.new(0.05, 0, 0, 220)
btnDrillSize.Text = "Drill Hitbox: 1x"
btnDrillSize.BackgroundColor3 = Color3.fromRGB(60, 100, 150)
btnDrillSize.TextColor3 = Color3.new(1, 1, 1)

local btnWalkSpeed = Instance.new("TextButton", contentFrame)
btnWalkSpeed.Size = UDim2.new(0.9, 0, 0, 30)
btnWalkSpeed.Position = UDim2.new(0.05, 0, 0, 260)
btnWalkSpeed.Text = "WalkSpeed: 16"
btnWalkSpeed.BackgroundColor3 = Color3.fromRGB(150, 80, 40)
btnWalkSpeed.TextColor3 = Color3.new(1, 1, 1)

local btnTpPlot = Instance.new("TextButton", contentFrame)
btnTpPlot.Size = UDim2.new(0.9, 0, 0, 30)
btnTpPlot.Position = UDim2.new(0.05, 0, 0, 300)
btnTpPlot.Text = "TP to Plot"
btnTpPlot.BackgroundColor3 = Color3.fromRGB(80, 150, 80)
btnTpPlot.TextColor3 = Color3.new(1, 1, 1)

local btnExplode = Instance.new("TextButton", contentFrame)
btnExplode.Size = UDim2.new(0.9, 0, 0, 30)
btnExplode.Position = UDim2.new(0.05, 0, 0, 340)
btnExplode.Text = "Spawn Explosion"
btnExplode.BackgroundColor3 = Color3.fromRGB(150, 80, 20)
btnExplode.TextColor3 = Color3.new(1, 1, 1)

local btnTerminate = Instance.new("TextButton", contentFrame)
btnTerminate.Size = UDim2.new(0.9, 0, 0, 30)
btnTerminate.Position = UDim2.new(0.05, 0, 0, 380)
btnTerminate.Text = "Terminate"
btnTerminate.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
btnTerminate.TextColor3 = Color3.new(1, 1, 1)

-- ==========================================
-- 2. Helper Functions & Scanners
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

-- TARGETED VEHICLE SCANNER
local function getVehicleCargoData()
    local isFull = false
    local cargoText = nil
    
    pcall(function()
        local vehiclesFolder = workspace:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, vehicle in ipairs(vehiclesFolder:GetChildren()) do
                if vehicle:IsA("Model") then
                    
                    local cargoVolume = vehicle:FindFirstChild("CargoVolume")
                    if cargoVolume then
                        -- Count literal number of items (ores, welds, meshes) in the folder
                        local currentCount = #cargoVolume:GetChildren()
                        
                        -- Estimate actual ore count for display (current parts / 2)
                        local estimatedOres = math.floor(currentCount / (MAX_CARGO_CHILDREN / VEHICLE_CAPACITY))
                        if estimatedOres > VEHICLE_CAPACITY then estimatedOres = VEHICLE_CAPACITY end
                        
                        cargoText = tostring(estimatedOres) .. " / " .. tostring(VEHICLE_CAPACITY) .. " [Raw: " .. tostring(currentCount) .. "]"
                        
                        if currentCount >= MAX_CARGO_CHILDREN then
                            isFull = true
                        end
                        return 
                    end
                    
                    local current = vehicle:GetAttribute("StoredOres") or vehicle:GetAttribute("Cargo") or vehicle:GetAttribute("OreCount")
                    local maxCap = vehicle:GetAttribute("Capacity") or vehicle:GetAttribute("MaxCapacity")
                    
                    if current and maxCap and tonumber(maxCap) == VEHICLE_CAPACITY then
                        cargoText = tostring(current) .. " / " .. tostring(maxCap)
                        if tonumber(current) >= tonumber(maxCap) then
                            isFull = true
                        end
                        return
                    end
                end
            end
        end
    end)
    
    return isFull, cargoText
end

-- ==========================================
-- DRILL ZONE MODIFIER LOGIC
-- ==========================================
local drillMultipliers = {1, 3, 5, 10, 20}
local currentDrillIndex = 1

local function applyDrillSize()
    local multi = drillMultipliers[currentDrillIndex]
    
    pcall(function()
        -- Safely step through the hierarchy so it doesn't break if the drill despawns
        local vehicles = workspace:FindFirstChild("Vehicles")
        local exaDrill = vehicles and vehicles:FindFirstChild("ExaDrill")
        local body = exaDrill and exaDrill:FindFirstChild("Body")
        local drillZone = body and body:FindFirstChild("DrillZone")
        
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
    end)
end

btnDrillSize.MouseButton1Click:Connect(function()
    currentDrillIndex = currentDrillIndex + 1
    if currentDrillIndex > #drillMultipliers then
        currentDrillIndex = 1
    end
    
    local multi = drillMultipliers[currentDrillIndex]
    btnDrillSize.Text = "Drill Hitbox: " .. multi .. "x"
    applyDrillSize()
end)

-- ==========================================
-- WALK SPEED MODIFIER LOGIC
-- ==========================================
local walkSpeeds = {16, 32, 64, 100}
local currentSpeedIndex = 1

local function applyWalkSpeed()
    local speed = walkSpeeds[currentSpeedIndex]
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = speed
        end
    end
end

btnWalkSpeed.MouseButton1Click:Connect(function()
    currentSpeedIndex = currentSpeedIndex + 1
    if currentSpeedIndex > #walkSpeeds then
        currentSpeedIndex = 1
    end
    
    local speed = walkSpeeds[currentSpeedIndex]
    btnWalkSpeed.Text = "WalkSpeed: " .. speed
    applyWalkSpeed()
end)

task.spawn(function()
    while task.wait(0.5) do
        if currentSpeedIndex > 1 then
            applyWalkSpeed()
        end
    end
end)

-- ==========================================
-- 3. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Time: N/A"
    
    pressKey(Enum.KeyCode.E, 0.1)
    safeWait(0.28)
    
    local hrp = getHRP()
    if hrp then
        wp2 = hrp.CFrame
    end
    
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
        applyDrillSize()
        
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
    
    lblStatus.Text = "Status: Exiting Vehicle..."
    pressKey(Enum.KeyCode.Space, 0.1)
    safeWait(0.5)
    
    lblStatus.Text = "Status: Backing up..."
    holdKey(Enum.KeyCode.S)
    safeWait(2.5) 
    releaseKey(Enum.KeyCode.S)
end

-- ==========================================
-- 4. Main Loop & Events
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
    lblCountdown.Text = "Time: 0s"
    loopActive = false
end

local minimized = false
btnMinimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        frame.Size = UDim2.new(0, 200, 0, 30)
        contentFrame.Visible = false
        btnMinimize.Text = "+"
    else
        frame.Size = UDim2.new(0, 200, 0, 450)
        contentFrame.Visible = true
        btnMinimize.Text = "-"
    end
end)

btnSetWp1.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if hrp then
        wp1 = hrp.CFrame
        btnSetWp1.Text = "WP 1 Set!"
        btnSetWp1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    else
        btnSetWp1.Text = "Spawn First!"
        task.wait(1)
        btnSetWp1.Text = "Set WP 1"
    end
end)

local function startScript()
    if not wp1 then
        btnStart.Text = "Set WP 1 First!"
        task.wait(1)
        if not isRunning then btnStart.Text = "Start" end
        return
    end
    
    btnStart.Text = "Running..."
    btnStart.BackgroundColor3 = Color3.fromRGB(30, 120, 30)
    
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
        btnPause.BackgroundColor3 = Color3.fromRGB(150, 150, 40)
    else
        btnPause.Text = "Pause"
        btnPause.BackgroundColor3 = Color3.fromRGB(150, 100, 20)
    end
end)

btnForceUnload.MouseButton1Click:Connect(function()
    if isRunning then
        forceUnloadTrigger = true
        lblStatus.Text = "Status: Forcing Unload..."
    else
        if not wp1 then
            btnForceUnload.Text = "Set WP1 First!"
            task.wait(1)
            btnForceUnload.Text = "Force Unload"
            return
        end
        isRunning = true
        task.spawn(function()
            unloadFunc()
            isRunning = false
            lblStatus.Text = "Status: Idle"
            lblCountdown.Text = "Time: 0s"
        end)
    end
end)

btnTpPlot.MouseButton1Click:Connect(function()
    local plotId = player:GetAttribute("Plot") or player:GetAttribute("PlotID") or player:GetAttribute("PlotId") or player:GetAttribute("plot")
    
    if not plotId then
        local plotVal = player:FindFirstChild("Plot") or player:FindFirstChild("PlotID") or player:FindFirstChild("PlotId")
        if plotVal then
            plotId = plotVal.Value
        end
    end

    local plotsFolder = workspace:FindFirstChild("Plots")
    local targetPlot = nil

    if plotsFolder then
        if plotId then
            targetPlot = plotsFolder:FindFirstChild(tostring(plotId))
        end

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
