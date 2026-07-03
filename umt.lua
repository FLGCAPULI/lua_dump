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
frame.Size = UDim2.new(0, 200, 0, 220)
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

local btnTerminate = Instance.new("TextButton", contentFrame)
btnTerminate.Size = UDim2.new(0.9, 0, 0, 30)
btnTerminate.Position = UDim2.new(0.05, 0, 0, 140)
btnTerminate.Text = "Terminate (or Press 0)"
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

-- ==========================================
-- 3. Core Logic Functions
-- ==========================================
local function unloadFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Unloading..."
    lblCountdown.Text = "Time: N/A"
    
    -- Press E on the prompt
    pressKey(Enum.KeyCode.E, 0.1)
    task.wait(0.1)
    
    -- Set wp 2
    wp2 = hrp.CFrame
    
    -- Sequence: TP WP1 -> E -> TP WP2 -> E (Repeated)
    for i = 1, 4 do
        teleport(wp1)
        pressKey(Enum.KeyCode.E, 0.1)
        task.wait(0.1)
        
        teleport(wp2)
        if i < 4 then -- Don't press E on WP2 the final time before driving, based on prompt
            pressKey(Enum.KeyCode.E, 0.1)
            task.wait(0.1)
        end
    end

    -- Press W until Drive prompt popups, then press E
    holdKey(Enum.KeyCode.W)
    -- Note: Adjust this wait time based on how long it takes to reach the vehicle
    task.wait(2) 
    releaseKey(Enum.KeyCode.W)
    
    task.wait(0.1)
    pressKey(Enum.KeyCode.E, 0.1) -- Press E on drive prompt
end

local function mineFunc()
    if not isRunning then return end
    
    lblStatus.Text = "Status: Mining..."
    lblCountdown.Text = "Time: 60s"
    
    -- Press W for 1 min
    holdKey(Enum.KeyCode.W)
    
    -- Wait 60 seconds (broken into smaller checks to allow early termination and countdown updates)
    for i = 1, 600 do
        if not isRunning then break end
        
        -- Update countdown label every full second (10 ticks = 1 second)
        if i % 10 == 0 then
            lblCountdown.Text = "Time: " .. tostring(60 - (i/10)) .. "s"
        end
        
        task.wait(0.1)
    end
    releaseKey(Enum.KeyCode.W)
    
    task.wait(0.1)
    
    lblStatus.Text = "Status: Exiting Vehicle..."
    -- Press space to get out of vehicle
    pressKey(Enum.KeyCode.Space, 0.1)
    task.wait(0.5)
    
    lblStatus.Text = "Status: Backing up..."
    -- Press S until another prompt popups
    holdKey(Enum.KeyCode.S)
    -- Note: Adjust this wait time based on how far you need to back up
    task.wait(2.5) 
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
        frame.Size = UDim2.new(0, 200, 0, 220)
        contentFrame.Visible = true
        btnMinimize.Text = "-"
    end
end)

btnSetWp1.MouseButton1Click:Connect(function()
    wp1 = hrp.CFrame
    btnSetWp1.Text = "WP 1 Set!"
    btnSetWp1.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
end)

btnStart.MouseButton1Click:Connect(function()
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
        task.spawn(mainLoop)
    end
end)

local function terminateScript()
    isRunning = false
    -- Ensure keys are released if terminated mid-action
    releaseKey(Enum.KeyCode.W)
    releaseKey(Enum.KeyCode.S)
    
    screenGui:Destroy()
    print("Script Terminated.")
end

btnTerminate.MouseButton1Click:Connect(terminateScript)

-- Hotkey 0 to terminate
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Zero then
        terminateScript()
    end
end)
