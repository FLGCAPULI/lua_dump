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
-- Using CoreGui if in an executor, otherwise PlayerGui (change if needed)
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
    if hrp and cframe then
        hrp.CFrame = cframe
        task.wait(0.1) -- Minimal delay to allow server to register position
    end
end

local function safeWait(waitTime)
    local elapsed = 0
    while elapsed < waitTime do
        if not isRunning then break end
        
        -- Handle Pause logic anywhere there is a delay
        if isPaused then
            local prevStatus = lblStatus.Text
            lblStatus.Text = "Status: PAUSED"
            releaseKey(Enum.KeyCode.W)
            releaseKey(Enum.KeyCode.S)
            
            repeat task.wait(0.2) until not isPaused or not isRunning
            
            if not isRunning then break end
            lblStatus.Text = prevStatus
            
            -- Re-apply movement keys if we were mining/moving
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

local function checkVehicleFull()
    local success, result = pcall(function()
        if not hrp then return false end
        
        local foundFull = false
        local latestCargo = nil
        
        -- Scan the workspace for 3D Text popups (BillboardGuis)
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("TextLabel") then
                local text = v.ContentText ~= "" and v.ContentText or v.Text
                if text and text ~= "" then
                    -- Verify it's a physical GUI in the 3D world
                    local gui = v:FindFirstAncestorOfClass("BillboardGui") or v:FindFirstAncestorOfClass("SurfaceGui")
                    if gui then
                        -- Check distance (60 studs) to ensure it's OUR vehicle's popups, not another player's
                        local adornee = gui.Adornee or (gui.Parent and gui.Parent:IsA("BasePart") and gui.Parent)
                        if adornee and (adornee.Position - hrp.Position).Magnitude < 60 then
                            local lowerText = string.lower(text)
                            
                            -- 1. Check for the red "VEHICLE FULL" popup
                            if string.find(lowerText, "vehicle full") then
                                foundFull = true
                            end
                            
                            -- 2. Try to parse live numbers from popups like "+1 Cobalt (11/120)"
                            local currentStr, maxStr = string.match(text, "%((%d+)/(%d+)%)")
                            if currentStr and maxStr then
                                latestCargo = currentStr .. " / " .. maxStr
                            end
                        end
                    end
                end
            end
        end
        
        -- Update the UI with the live numbers parsed from the flying popups!
        if latestCargo then
            lblCountdown.Text = "Cargo: " .. latestCargo
        end
        
        return foundFull
    end)
    
    if not success then 
        warn("Error checking full status: ", result) 
    end
    
    return success and result
end

-- ==========================================
-- 3. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Time: N/A"
    
    -- Press E on the prompt
    pressKey(Enum.KeyCode.E, 0.1)
    safeWait(0.28) -- Added 180ms delay
    
    -- Set wp 2
    wp2 = hrp.CFrame
    
    -- Sequence: TP WP1 -> E -> TP WP2 -> E (Repeated)
    for i = 1, 4 do
        teleport(wp1)
        safeWait(0.18) -- Extra 180ms delay to allow server to register TP before prompt appears
        pressKey(Enum.KeyCode.E, 0.1)
        safeWait(0.28) -- Added 180ms delay
        
        teleport(wp2)
        safeWait(0.18) -- Extra 180ms delay to allow server to register TP before prompt appears
        if i < 4 then -- Don't press E on WP2 the final time before driving, based on prompt
            pressKey(Enum.KeyCode.E, 0.1)
            safeWait(0.28) -- Added 180ms delay
        end
    end

    -- Press W until Drive prompt popups, then press E
    lblStatus.Text = "Status: Walking to Drive..."
    holdKey(Enum.KeyCode.W)
    -- Note: Adjust this wait time based on how long it takes to reach the vehicle
    safeWait(2) 
    releaseKey(Enum.KeyCode.W)
    
    safeWait(0.28) -- Added 180ms delay
    pressKey(Enum.KeyCode.E, 0.1) -- Press E on drive prompt
end

local function mineFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Mining..."
    lblCountdown.Text = "Cargo: Checking..."
    
    -- Press W indefinitely until vehicle is full
    holdKey(Enum.KeyCode.W)
    
    while isRunning do
        safeWait(0.5) -- Uses our new safeWait which handles pausing automatically
        
        -- Handle force early unload logic
        if forceUnloadTrigger then
            forceUnloadTrigger = false
            break
        end
        
        -- Handle Auto-unload logic
        if checkVehicleFull() then
            break
        end
    end
    
    releaseKey(Enum.KeyCode.W)
    if not isRunning then return end
    
    task.wait(0.1)
    
    lblStatus.Text = "Status: Exiting Vehicle..."
    -- Press space to get out of vehicle
    pressKey(Enum.KeyCode.Space, 0.1)
    safeWait(0.5)
    
    lblStatus.Text = "Status: Backing up..."
    -- Press S until another prompt popups
    holdKey(Enum.KeyCode.S)
    -- Note: Adjust this wait time based on how far you need to back up
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
        task.wait(0.1) -- Minimal delay to prevent crashing
    end
    lblStatus.Text = "Status: Idle"
    lblCountdown.Text = "Time: 0s"
    loopActive = false
end

-- GUI Button Events
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
        -- If idle, run unload standalone
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
    -- Ensure keys are released if terminated mid-action
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.S)
    
    screenGui:Destroy()
    print("Script Terminated.")
end

btnTerminate.MouseButton1Click:Connect(terminateScript)

-- Hotkeys: 0 to Start, Left Ctrl to Toggle GUI Visibility
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.Zero then
            startScript()
        elseif input.KeyCode == Enum.KeyCode.LeftControl then
            screenGui.Enabled = not screenGui.Enabled
        end
    end
end)
