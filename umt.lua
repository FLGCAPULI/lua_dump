local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local wp1 = nil
local wp2 = nil
local isRunning = false
local loopActive = false
local isPaused = false
local forceUnloadTrigger = false

-- CONFIGURATION
local VEHICLE_CAPACITY = 120 -- Change this number if you upgrade your vehicle's storage later

-- ==========================================
-- 1. GUI Setup
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoFarmGUI"
screenGui.ResetOnSpawn = false
local success, err = pcall(function() screenGui.Parent = CoreGui end)
if not success then screenGui.Parent = player.PlayerGui end

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 200, 0, 290)
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

local btnTerminate = Instance.new("TextButton", contentFrame)
btnTerminate.Size = UDim2.new(0.9, 0, 0, 30)
btnTerminate.Position = UDim2.new(0.05, 0, 0, 220)
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
    
    local function evaluateText(text)
        if not text or text == "" then return end
        local lowerText = string.lower(text)
        
        -- 1. Check for literal red "VEHICLE FULL" text
        if string.find(lowerText, "vehicle full") then
            isFull = true
        end
        
        -- 2. Extract "(11/120)" style patterns
        local cStr, mStr = string.match(lowerText, "(%d+)%s*/%s*(%d+)")
        if cStr and mStr then
            local current = tonumber(cStr)
            local maxCap = tonumber(mStr)
            
            -- ENSURE max capacity matches the drill! (This ignores your 100/100 Health Bar)
            if maxCap == VEHICLE_CAPACITY then
                cargoText = tostring(current) .. " / " .. tostring(maxCap)
                if current >= maxCap then
                    isFull = true
                end
            end
        end
    end

    pcall(function()
        -- Scan A: Check Workspace.Vehicles folder (Fast & Targetted)
        local vehiclesFolder = workspace:FindFirstChild("Vehicles")
        if vehiclesFolder then
            for _, vehicle in ipairs(vehiclesFolder:GetChildren()) do
                if vehicle:IsA("Model") then
                    -- Check Attributes
                    local current = vehicle:GetAttribute("StoredOres") or vehicle:GetAttribute("Cargo") or vehicle:GetAttribute("OreCount")
                    local maxCap = vehicle:GetAttribute("Capacity") or vehicle:GetAttribute("MaxCapacity")
                    
                    if current and maxCap and tonumber(maxCap) == VEHICLE_CAPACITY then
                        cargoText = tostring(current) .. " / " .. tostring(maxCap)
                        if tonumber(current) >= tonumber(maxCap) then
                            isFull = true
                        end
                    end
                    
                    -- Check physical TextLabels on the vehicle model
                    for _, desc in ipairs(vehicle:GetDescendants()) do
                        if desc:IsA("TextLabel") then
                            evaluateText(desc.ContentText ~= "" and desc.ContentText or desc.Text)
                        end
                    end
                end
            end
        end
        
        -- Scan B: Check PlayerGui (In case the popups are actually 2D UI rendered above the screen)
        for _, desc in ipairs(player.PlayerGui:GetDescendants()) do
            if desc:IsA("TextLabel") then
                evaluateText(desc.ContentText ~= "" and desc.ContentText or desc.Text)
            end
        end
    end)
    
    return isFull, cargoText
end

-- ==========================================
-- 3. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Time: N/A"
    
    pressKey(Enum.KeyCode.E, 0.1)
    safeWait(0.28)
    
    wp2 = hrp.CFrame
    
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
        -- Constantly fetch the live state every 0.5 seconds
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
        frame.Size = UDim2.new(0, 200, 0, 290)
        contentFrame.Visible = true
        btnMinimize.Text = "-"
    end
end)

btnSetWp1.MouseButton1Click:Connect(function()
    wp1 = hrp.CFrame
    btnSetWp1.Text = "WP 1 Set!"
    btnSetWp1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
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
