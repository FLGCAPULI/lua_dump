local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local TARGET_NAME = "Obsidian"

-- ==========================================
-- 🛠️ STATE VARIABLES (Toggle Flags)
-- ==========================================
local states = {
    Method1 = false, -- Radius Deletion/NoCollide
    Method2 = false, -- Stuck Detection & Reverse
    Method3 = false, -- Raycast Avoidance
    Method4 = false  -- Auto-C4 Mock
}

-- ==========================================
-- 🎨 GUI CREATION
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
-- Attempt to parent to CoreGui (exploit standard) to hide from anti-cheats, fallback to PlayerGui
local success = pcall(function() ScreenGui.Parent = CoreGui end)
if not success then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true -- Allows you to drag the GUI around
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "⛏️ Obstacle Bypass Tester"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -50)
Container.Position = UDim2.new(0, 10, 0, 40)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 10)
UIListLayout.Parent = Container

-- Helper function to create toggle buttons
local function createButton(name, text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 50)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 14
    btn.TextWrapped = true
    btn.Parent = Container
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        states[name] = not states[name]
        if states[name] then
            btn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
        print("Toggled " .. name .. ": " .. tostring(states[name]))
    end)
end

createButton("Method1", "1. Radius No-Collide (Easy)")
createButton("Method2", "2. Stuck Detect & Reverse (Brute)")
createButton("Method3", "3. Raycast Avoidance (Smart AI)")
createButton("Method4", "4. Auto-C4 Demo (Mechanic)")

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(1, 0, 0, 40)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "Destroy GUI"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Container
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
    -- Turn off all logic loops
    for k, v in pairs(states) do states[k] = false end
end)

-- ==========================================
-- ⚙️ LOGIC & THEORIES
-- ==========================================
local function getCenter()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart then
        return hum.SeatPart.Position, hum.SeatPart.CFrame.LookVector
    elseif hrp then
        return hrp.Position, hrp.CFrame.LookVector
    end
    return nil, nil
end

-- METHOD 1: Radius No-Collide (Constantly running in background if enabled)
RunService.Stepped:Connect(function()
    if not states.Method1 then return end
    local pos, _ = getCenter()
    if not pos then return end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {LocalPlayer.Character}

    local parts = workspace:GetPartBoundsInRadius(pos, 35, overlapParams)
    for _, part in ipairs(parts) do
        if string.find(string.lower(part.Name), string.lower(TARGET_NAME)) then
            part.CanCollide = false
            part.Transparency = 0.5
        end
    end
end)

-- METHOD 2: Stuck Detection & Auto Reverse
task.spawn(function()
    local lastPos = nil
    while task.wait(2) do
        if not states.Method2 then lastPos = nil continue end
        local pos, _ = getCenter()
        if not pos then continue end

        if lastPos then
            local distance = (pos - lastPos).Magnitude
            -- If we moved less than 2 studs in 2 seconds, we are stuck!
            if distance < 2 then
                print("[Method 2] Stuck detected! Reversing...")
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game) -- Release W
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, game) -- Hold S
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game) -- Turn Left
                task.wait(1.5)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game) -- Release S
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game) -- Release A
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)  -- Resume W
            end
        end
        lastPos = pos
    end
end)

-- METHOD 3: Raycast Obstacle Avoidance
RunService.Heartbeat:Connect(function()
    if not states.Method3 then return end
    local pos, lookVec = getCenter()
    if not pos or not lookVec then return end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}

    -- Cast a ray 25 studs straight ahead
    local result = workspace:Raycast(pos, lookVec * 25, rayParams)

    if result and result.Instance then
        if string.find(string.lower(result.Instance.Name), string.lower(TARGET_NAME)) then
            -- Obstacle ahead! Steer away.
            print("[Method 3] Obsidian detected ahead! Steering right...")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game) -- Hold D
        else
            -- Path is clear
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game) -- Release D
        end
    else
         VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game) -- Release D
    end
end)

-- METHOD 4: Auto-C4 Deployment (Mock)
task.spawn(function()
    while task.wait(0.5) do
        if not states.Method4 then continue end
        local pos, lookVec = getCenter()
        if not pos or not lookVec then continue end

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
        
        -- Check 15 studs ahead
        local result = workspace:Raycast(pos, lookVec * 15, rayParams)
        if result and result.Instance and string.find(string.lower(result.Instance.Name), string.lower(TARGET_NAME)) then
            print("[Method 4] Obstacle found. Stopping vehicle...")
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game) -- Stop moving
            task.wait(0.5)
            
            print("[Method 4] Equipping C4 (Pressing 3)...")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game)
            task.wait(0.5)
            
            print("[Method 4] Simulating mouse click to place C4...")
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            task.wait(0.5)
            
            print("[Method 4] Backing up...")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, game)
            task.wait(1.5)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, game)
            
            print("[Method 4] Detonating! (Pressing F)")
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            
            -- Wait a moment for explosion, then drive forward again
            task.wait(1)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            
            -- Wait a few seconds before we can scan for C4 again to prevent spam
            task.wait(5)
        end
    end
end)
