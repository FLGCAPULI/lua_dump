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
frame.Size = UDim2.new(0, 200, 0, 190)
frame.Position = UDim2.new(0, 10, 0, 10)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "Auto Farm Script"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1

local btnSetWp1 = Instance.new("TextButton", frame)
btnSetWp1.Size = UDim2.new(0.9, 0, 0, 30)
btnSetWp1.Position = UDim2.new(0.05, 0, 0, 40)
btnSetWp1.Text = "Set WP 1"
btnSetWp1.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
btnSetWp1.TextColor3 = Color3.new(1, 1, 1)

local btnStart = Instance.new("TextButton", frame)
btnStart.Size = UDim2.new(0.9, 0, 0, 30)
btnStart.Position = UDim2.new(0.05, 0, 0, 80)
btnStart.Text = "Start"
btnStart.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
btnStart.TextColor3 = Color3.new(1, 1, 1)

local btnTerminate = Instance.new("TextButton", frame)
btnTerminate.Size = UDim2.new(0.9, 0, 0, 30)
btnTerminate.Position = UDim2.new(0.05, 0, 0, 120)
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
    
    -- Press W for 1 min
    holdKey(Enum.KeyCode.W)
    
    -- Wait 60 seconds (broken into smaller checks to allow early termination)
    for i = 1, 600 do
        if not isRunning then break end
        task.wait(0.1)
    end
    releaseKey(Enum.KeyCode.W)
    
    task.wait(0.1)
    
    -- Press space to get out of vehicle
    pressKey(Enum.KeyCode.Space, 0.1)
    task.wait(0.5)
    
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
    loopActive = false
end

-- GUI Button Events
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
